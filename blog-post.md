# Running gbrain fully local: a second brain that never phones home

I wanted a personal knowledge base that could actually answer questions across my
notes, with citations, and I wanted it to run entirely on my laptop. No OpenAI
key. No Anthropic key. No cloud database. Nothing about what I write leaving the
machine.

That is what this walkthrough builds: [gbrain](https://github.com/garrytan/gbrain)
wired so that a local model does the thinking, a local model does the
remembering, and a file on disk does the storing.

Along the way I hit one trap that every "just use Ollama" guide gets wrong. I
will show you the trap, because understanding why it fails is the fastest way to
understand how the whole thing fits together.

## First: what is gbrain, and why bother

gbrain is a searchable memory that answers questions about your own notes — and
cites the note it used.

Not a note app. Not a generic chatbot. Something in the gap between them.

You feed it decisions, people, meetings, whole documents. Later you ask a
question, and it finds the relevant notes and writes an answer built from *your*
pages.

Why that gap matters: the two tools you already have both fail, in opposite ways.

Search gives you ten links and makes you do the reading.

A chatbot writes a confident answer, but it has never seen your notes — ask it
"what did *we* decide about pricing?" and it guesses.

gbrain reads your actual pages and answers from them:

```
you:     "Why was the base tier price raised?"
gbrain:  "Raised from $19 to $29 because support costs per seat grew and the
          $19 tier was unprofitable below 50 seats [pricing-decision]."
```

The answer is built from your note, and it names the page, so you can trust it.
And when it does not know, it says so — an honest "I don't have that" instead of
a confident wrong answer.

So the reasons to run it: your context stops evaporating, you can ask across
everything you have ever written at once, and — wired into a coding agent — it
gives that agent a memory so it stops re-asking what it could look up. In this
build, all of that stays on your laptop.

One caveat worth saying up front: an empty brain answers nothing, so day one
feels broken. It earns its keep once capturing becomes a habit.

Everything below was built and verified on an Apple M5 with 32 GB. One running
example carries through the whole post: a folder with two notes in it.

```
pricing-decision.md   "raise the base tier from $19 to $29 in July..."
hiring.md             "freeze backend hiring until the pricing change lands..."
```

By the end, I can ask "why was the price raised, and what hiring change
followed?" and get a cited answer, with zero network calls.

## The shape of the machine

Before any commands, here is the whole system on one screen. Follow the arrows.

```
your notes (markdown)
      ↓
Ollama · nomic-embed-text   turns each note into 768 numbers      (embeddings)
      ↓
PGLite · a file on disk     stores the notes and the numbers      (memory)
      ↓   ← your question comes in here, gets turned into numbers too
find the closest notes by comparing numbers
      ↓
Ollama · qwen2.5:14b        reads those notes, writes the answer   (generation)
```

Three actors. Ollama runs the models. PGLite holds everything. gbrain is the CLI
that moves data between them.

Keep that picture. Every section below is just one arrow in it.

## Two models, because there are two different jobs

The first thing that trips people up: you need two models, not one, and they are
not interchangeable.

**One model turns text into numbers.**

You hand it a sentence. It hands back a list of 768 numbers.

That list is called an embedding. Similar sentences produce similar lists. That
is the entire reason search will work later.

**The other model turns notes into an answer.**

You hand it your question plus the notes that matched. It writes prose back.

An embedding model cannot write you a paragraph. A chat model *could* produce an
embedding, but it is huge and slow for a job that runs on every single note. So
gbrain uses one of each:

```bash
ollama pull nomic-embed-text     # embeddings · 768 dims · ~274 MB
ollama pull qwen2.5:14b          # generation · ~9 GB
```

`ollama pull` downloads the weights to `~/.ollama/models` once. After that they
load from local disk, and nothing about them touches the network again.

An embedding is not an AI conversation. It is not something the chat model does.
It is a separate, tiny, constant job — and it needs its own small model.

## Ingestion: how a note becomes a memory

Here is the first arrow. It runs entirely on your machine.

```bash
gbrain import ~/notes
# Found 2 markdown files
# 2 pages imported, 2 chunks created
```

Walk through what "2 chunks created" actually means.

gbrain reads each file, splits it into chunks, and sends each chunk to Ollama to
be embedded. Ollama returns 768 numbers per chunk. gbrain writes the chunk text
*and* its 768 numbers into the database.

The naive version skips the chunking and embeds the whole file as one blob. That
breaks the moment a file covers two topics: the pricing note and a paragraph
about, say, office snacks would share one averaged vector, and neither would be
findable on its own. Splitting first keeps each idea searchable.

Where does the database live? In a single folder:

```
~/.gbrain/brain.pglite
```

That is PGLite. It is Postgres, compiled to run *inside* gbrain instead of as a
separate server you install and start. No port. No password. No `postgres`
process. You could copy that folder to another Mac and it would just work.

So after ingestion:

- **Where it ran:** your machine. gbrain locally, Ollama locally.
- **What got stored:** the note text and its 768-number vector, in the PGLite file.
- **What was computed once:** the embeddings. They are not recomputed when you search.
- **What it hands to the next step:** a database full of (text, vector) rows, ready to be matched.

This is worth saying plainly: embedding happens at import time, once. Your
question, later, is the only thing embedded fresh.

## Asking: how a question finds its answer

Now the interesting arrow.

```bash
gbrain think "What did we decide about pricing and why?"
```

Four things happen, in order:

```
your question
   ↓  Ollama embeds it into 768 numbers        (fresh, every time)
   ↓  PGLite finds the note-vectors closest to it
   ↓  gbrain hands those notes + your question to qwen2.5:14b
   ↓  qwen writes an answer that cites the notes
```

The search step is pure math. "Closest" means the note vectors whose 768 numbers
point in nearly the same direction as your question's 768 numbers. No AI runs
during the search — it is comparing lists of numbers the embedding model already
produced.

Only the last step is generation. The model does not know your notes; it is
*handed* them, in the prompt, and told to answer using only those. That is why
the answer can cite `[pricing-decision]`: the note was in front of it.

Here is the real answer it gave:

> We decided to raise the base tier from $19 to $29/month starting July because
> support costs per seat increased and the $19 tier was unprofitable below 50
> seats `[pricing-decision]`. Existing customers are grandfathered at $19 for 12
> months.

Retrieval prepared the knowledge. Search found the knowledge. The model explained
the knowledge. Now the only question left is: how do we make that last model
local?

## The trap: `ollama:` does not work for chat

This is the part every shortcut guide gets wrong, so slow down here.

Embeddings used `ollama:nomic-embed-text`. The obvious next move is to point
generation at Ollama the same way:

```bash
gbrain config set chat_model ollama:qwen2.5:14b
gbrain think "Why was the price raised?"
```

And you get this:

```
(no LLM available — set ANTHROPIC_API_KEY or pass `client`)
Model: ollama:qwen2.5:14b | Pages: 2 | Warnings: NO_ANTHROPIC_API_KEY
```

Look closely, because the output is almost taunting you. It *knows* the model is
`ollama:qwen2.5:14b`. It found 2 pages. Then it refused to write anything and
asked for a cloud key.

The retrieval ran locally. The synthesis quit.

### Why it quits: recipes and touchpoints

gbrain reaches every provider through a **recipe** — a small description of one
provider: its URL, how it authenticates, and which jobs it can do.

Those jobs are called **touchpoints**. There are three: `embedding`, `chat`,
`reranker`.

Here is the actual Ollama recipe shipped inside gbrain, trimmed to the point:

```
ollama recipe
  touchpoints:
    embedding: ✓   (nomic-embed-text, mxbai-embed-large, all-minilm)
    chat:      ✗   (not declared)
```

That is the whole explanation. The Ollama recipe declares `embedding` and nothing
else. When you ask gbrain to *chat* with Ollama, it checks the recipe, finds no
`chat` touchpoint, and silently falls back to its built-in default — a cloud
model that needs a key.

This is not your fault, and it is not a bug you can config your way out of. It is
a known, open gap: gbrain's own `COMMUNITY_IDEAS.md` lists "local-first chat
parity" and "litellm proxy unusable for chat" as open issues. Today, Ollama is
wired for embeddings only.

### The fix: borrow a recipe that has chat

We need a recipe that *does* declare `chat` and that lets us change its URL to
point at Ollama. Of the chat-capable recipes, the OpenAI-compatible ones can be
repointed with an environment variable. `openrouter` is one.

The move:

```
openrouter recipe (has chat ✓, speaks the OpenAI API)
        ↓  change its base URL to...
http://localhost:11434/v1   (Ollama's OpenAI-compatible endpoint)
```

Ollama already speaks the OpenAI API. So gbrain believes it is calling
OpenRouter, and the request actually lands on Ollama, on your laptop.

```bash
export OPENROUTER_BASE_URL=http://localhost:11434/v1   # send openrouter calls to Ollama
export OPENROUTER_API_KEY=ollama                       # dummy; Ollama ignores auth
gbrain config set chat_model     openrouter:qwen2.5:14b
gbrain config set models.default openrouter:qwen2.5:14b
```

The dummy key exists only because gbrain checks that *a* key is present before it
will try. Ollama throws it away.

Two things I learned the hard way:

- **The base URL must be an environment variable.** `gbrain config set
  provider_base_urls.openrouter ...` looks like it works — `config get` even
  reads it back — but the gateway never reads that value. It reads
  `OPENROUTER_BASE_URL` from the environment. So it lives in a `env.sh` you
  source, not in the brain config.
- **A cold LLM can starve the query embedding.** The first question after a
  restart timed out its embedding at 6 seconds (Ollama was busy loading the 9 GB
  model) and returned an empty answer. Two exports fix it:

  ```bash
  export GBRAIN_QUERY_EMBED_TIMEOUT_MS=30000   # let the embed wait out the load
  export OLLAMA_KEEP_ALIVE=30m                  # keep the model warm
  ```

## Proof: watch the traffic, do not trust the claim

"Fully local" is a claim. The only way to trust it is to watch every model call
and confirm it landed on `localhost`.

So ask a real question and tail Ollama's log at the same time:

```bash
gbrain think "What did we decide about pricing and why?"
```

The answer comes back cited, `Model: openrouter:qwen2.5:14b | Citations: 1`. And
in Ollama's own log, at that exact moment:

```
200   25ms    POST  /v1/embeddings         ← the question became a vector
200   10.6s   POST  /v1/chat/completions   ← qwen wrote the answer
```

Two requests. Both to `127.0.0.1`. No Anthropic. No OpenAI. No key that reaches
the internet. That log is the whole point of the exercise — it is the difference
between "I think it is local" and "I watched it be local."

## Making it survive a reboot

Everything so far works *in this shell*. Close the terminal and two things
evaporate: the Ollama daemon (I started it by hand) and the four environment
variables (they only live in a file called `env.sh`). A real install has to
outlive the session. Two steps do that, and it is worth knowing what each one
actually produces.

**Step 1 — turn Ollama into a background service.**

```bash
brew services start ollama
```

This does not just run Ollama. It writes a launchd agent — a small file at
`~/Library/LaunchAgents/homebrew.mxcl.ollama.plist` — and hands it to macOS.
launchd is the thing that starts programs at login and restarts them if they die.

So what this *produces* is a daemon that is always there: it comes up when you
log in, relaunches itself if it crashes, and writes its log to
`/opt/homebrew/var/log/ollama.log`. You never type `ollama serve` again. `brew
services list` shows it as `started`.

```
ollama   started   ~/Library/LaunchAgents/homebrew.mxcl.ollama.plist
```

**Step 2 — load the environment in every shell.**

The four `export`s live in `env.sh`. To make every new terminal pick them up, add
one line to `~/.zshrc` (the file your shell runs on startup):

```bash
source ~/Projects/gbrain-ollama/env.sh
```

What this *produces* is that `OPENROUTER_BASE_URL`, `OPENROUTER_API_KEY`, and the
two timeout/keep-alive vars are set in every interactive shell you open. gbrain's
CLI reads them from the environment, so `gbrain think` finds the local route
without you sourcing anything by hand.

The test that proves both worked: open a brand-new terminal, type nothing but
`gbrain think "..."`, and watch `/opt/homebrew/var/log/ollama.log`. You should see
two `127.0.0.1` requests and a cited answer.

One honest caveat. The launchd daemon starts with a clean environment — it does
*not* read `env.sh` — so `OLLAMA_KEEP_ALIVE` from your shell does not reach it,
and it falls back to unloading an idle model after a few minutes. That is exactly
why `GBRAIN_QUERY_EMBED_TIMEOUT_MS=30000` matters: it lets the query embedding
wait out the occasional cold reload instead of timing out.

## Now actually use it: locally and globally

You have a running brain. Here is how you talk to it.

Everything you do is one of two things: putting knowledge *in*, or getting it
*out*.

```
   PUT IN                          GET OUT
   capture / import / put / sync   search / query / think
        ↓                                    ↑
              ~/.gbrain/brain.pglite
```

And one rule governs all of it: **gbrain only saves what it is told to save.**
Nothing is captured automatically — not your terminal, not your chats. Text
enters the brain when a write command runs, and only then.

### Locally, from the terminal

Putting things in:

```bash
gbrain capture "Decided to run gbrain fully local: Ollama + PGLite, no cloud."
gbrain import ~/notes/                 # a folder of markdown you already have
gbrain sync --repo ~/code/myproject    # a whole git repo
```

Getting things out — and the three commands are not the same:

```bash
gbrain search "pricing"                    # ranked pages, keyword — fast, no LLM
gbrain query  "why was the price raised?"  # hybrid (meaning + keywords), ranked pages
gbrain think  "why was the price raised?"  # a written, cited answer — uses the LLM
```

The practical difference, which I checked by watching Ollama's log: `search` and
`query` only ever hit `/v1/embeddings` — they hand you matching pages and need no
chat model. `think` is the only one that calls qwen to *write* an answer. So most
of your day-to-day retrieval does not even touch the generation model.

### Globally, from your coding agent

This is where it stops being a CLI and becomes a memory your agent shares. Wire
it in over MCP, globally:

```bash
claude mcp add gbrain -s user \
  -e OPENROUTER_BASE_URL=http://localhost:11434/v1 \
  -e OPENROUTER_API_KEY=ollama \
  -e GBRAIN_QUERY_EMBED_TIMEOUT_MS=30000 \
  -- gbrain serve
```

`-s user` is what makes it global. It writes the registration to `~/.claude.json`,
so the brain is available in *every* project on this machine — and because that
file belongs to your Mac user, not your Anthropic login, it stays available no
matter which Claude account you sign in with. Drop `-s user` and it registers for
the current project only. (If the agent later reports it can't find `gbrain`, an
MCP subprocess may not have your shell's PATH — swap `gbrain serve` for the
absolute path from `command -v gbrain`.)

Those `-e` flags are not optional on a local setup, and the reason ties back to
everything above. A coding agent launches `gbrain serve` with a clean
environment — it does not read your `~/.zshrc`. Skip the flags and brain *search*
still works (embeddings need no env), but *synthesis* over MCP falls back to "no
LLM available." The flags hand the local route straight to the subprocess.

Then teach the agent to use it, by pasting this into `CLAUDE.md`:

```markdown
## Brain-first protocol
You have a knowledge brain over MCP. Before answering about people, companies,
decisions, or past context: (1) search/query the brain first; (2) write new
decisions or ideas back with put_page; (3) cite the page you used.
```

Now the agent searches before it asks you, and writes decisions back as you work.
If you use [gstack](https://github.com/garrytan/gstack), two skills automate the
whole thing: `/setup-gbrain` does the wire-up and writes that protocol for you,
and `/sync-gbrain` indexes a code repo so `gbrain search` works semantically
across the codebase.

And to close the loop on the obvious worry: connecting your agent does *not*
record the conversation. The agent saves something only when it calls `put_page`
— decisions and new ideas, nothing else. You stay in control of what your brain
remembers.

## Is it fast enough for coding?

The honest first reaction to a local setup is: I asked a question and waited ten
seconds. Won't that wreck my flow?

It won't, and the reason is in the numbers. Measured on this brain:

| Command | Wall time | What Ollama did |
|---|---|---|
| `gbrain search "..."` | 1.1s | embeddings only (3–5ms) |
| `gbrain query "..."` | 0.6s | embeddings only (3–7ms) |
| `gbrain think "..."` | 8.6s | embeddings (2ms) + **chat ~5s** |

Read that with one question: where does the time go?

Not the embedding. That is 3 milliseconds.

Not the database. That is instant.

The 8.6 seconds is entirely qwen2.5:14b *writing* the answer, a token at a time,
on your laptop. A 14B local model is slower than a cloud one. That is the price of
nothing leaving the machine.

But look at *which* command pays it. Only `think`.

And your coding agent does not call `think`.

When Claude uses the brain while you code, it calls `search` and `query` — it
*fetches* your notes and reasons over them with its own fast model. It does not
ask the local 14B to write prose. Fetching is sub-second.

It is even faster than the table looks. Most of that 0.6–1.1s is the `gbrain` CLI
booting a fresh process. Over MCP, `gbrain serve` stays resident, so that cost is
paid once at session start, not per call. The agent's real lookups are an
embedding plus a database query — tens of milliseconds.

So the picture during development: a brain lookup returns in well under a second,
a rounding error next to the agent's own thinking time. The eight-second wait only
happens when *you* deliberately ask the brain to compose an answer with `think` —
not something the agent's loop does.

If you want `think` snappier too, three levers:

- **A smaller chat model.** `gbrain config set chat_model openrouter:qwen2.5:7b`
  (after `ollama pull qwen2.5:7b`) roughly halves generation time, for slightly
  weaker answers.
- **Keep it warm.** The cold runs earlier were 17–21s because qwen had to load
  into memory first; warm runs are 7–9s. An idle model unloads after a few
  minutes, so the first `think` after a break pays that reload. It never touches
  `search`/`query`.
- **Cloud chat for `think` only.** Point just the chat model at a real key if you
  want fast, high-quality synthesis and don't mind that one step leaving the
  machine. Retrieval stays fully local.

## Want a better brain, for free?

qwen2.5:14b is fine, but it is not Claude. So the obvious wish: can I just use the
good model I am already using in Claude Code, without a separate API key?

Directly, no — for two concrete reasons.

gbrain never asks the host to think for it. Even the `think` *tool*, called over
MCP, runs gbrain's own configured model, not Claude Code's.

And a Claude subscription is not a reusable API key. gbrain's `anthropic` recipe
wants a standalone `ANTHROPIC_API_KEY`, which is pay-per-token — a separate, paid
thing, not the login you already have.

But the outcome you want *is* free, and it is what the MCP wiring is actually for.
You flip who does the writing.

`gbrain think` makes *gbrain* synthesize, on the slow local model. Instead, let
Claude Code be the reasoning layer:

```
gbrain retrieves   — search / query, local, fast, free
Claude Code writes — with the frontier model you already use
```

So inside Claude Code you say "search my brain for X and explain it." Claude calls
the fast `search` tool, pulls your pages into its own context, and writes the
answer itself — Claude quality, no extra key, no local 14B. That is "use the
Claude Code model over my brain, for free," and the brain-first protocol already
nudges the agent toward `search`/`query` instead of the local `think`.

The honest caveat: those retrieved snippets go into Claude Code's context, so that
one step reaches Anthropic. No new key, the same trust boundary you already
accepted by using Claude Code — but not "nothing leaves the machine." Storage and
retrieval stay local.

And if you want gbrain's *own* `think` better, with no host in the loop:

- **Better, still fully local, still free** — a bigger local model. `gpt-oss:20b`
  (~13GB) sits comfortably on 32GB and beats 14B; `qwen2.5:32b` (~20GB) is higher
  quality still, but tight on RAM and slower.

  ```bash
  ollama pull gpt-oss:20b
  gbrain config set chat_model     openrouter:gpt-oss:20b
  gbrain config set models.default openrouter:gpt-oss:20b
  ```

- **Better, free, but not local** — a free cloud tier. Google Gemini (free key
  from AI Studio) or Groq (free tier); gbrain ships `google` and `groq` recipes.
  Higher quality than qwen, free within rate limits, but your notes go to that
  provider. Grab a key and set `chat_model` to `google:<model>` or `groq:<model>`
  (exact names via `gbrain providers env google`).

For coding, the best option is not in that last list at all — it is the one from a
few paragraphs up: **let Claude Code do the writing.** You are already sitting
inside the strong model, so let gbrain fetch and let Claude synthesize. Best
quality, no extra key. That is what connecting the brain was for in the first
place — the brain is Claude's memory to look things up in, not a second, weaker
model trying to answer in its place.

## How Claude actually talks to your brain

This is the part that surprised me, and it changes how you use the whole thing.

You do not run `gbrain think`.

You do not even type the word gbrain.

You ask Claude a question in plain English — "when's my birthday?" — and it answers
from your notes. No command. So how does that work?

### Claude learns your brain exists, at startup

When you ran `claude mcp add gbrain … -- gbrain serve`, you did not just save a
line of config. You told Claude Code: "there is a tool server here — launch it and
ask it what it can do."

So every time Claude Code starts, it:

1. Spawns `gbrain serve` as a background subprocess.
2. Asks it, over MCP, "what tools do you offer?"
3. Gets back a list — 92 of them: `search`, `query`, `put_page`, `get_page`, and
   so on, each with a one-line description of what it does.

Now your brain is just *there*, in Claude's toolbox, the same way it knows it can
read a file or run a command.

### What happens when you ask

Watch the birthday question flow through:

```
you (in Claude Code):  "when's my birthday?"
      ↓
Claude decides a brain lookup would help, and calls a tool:
      search({ query: "birthday" })              ← Claude → gbrain
      ↓
gbrain runs it locally: embed the query (Ollama, ~3ms), search PGLite
      ↓
      returns the page text: "on 3rd of march… born 1990"   ← gbrain → Claude
      ↓
Claude reads that in its own context and writes:
      "March 3rd; born in 1990, so you'll turn 36 this year."
```

Two things to notice.

**Claude chose to call the tool.** You did not tell it to. It saw a question about
you, remembered it has a brain tool, and reached for it — partly because the tool's
description says it searches your knowledge, and partly because the brain-first
protocol you pasted into `CLAUDE.md` tells it to look there first.

**gbrain never wrote a sentence.** It embedded, searched, and handed back a raw
page. The reasoning — the age math, "you'll turn 36" — is Claude's. gbrain was the
memory; Claude was the mind.

### Why it works: MCP is just a tool protocol

There is no magic here. MCP (Model Context Protocol) is a standard way for a
program to expose tools to an LLM. gbrain speaks it; Claude Code speaks it. When
they connect, Claude gets a menu of gbrain's tools with descriptions, and from
then on it can call any of them, read the result, and continue — the same tool-use
loop it runs for reading files or executing shell commands.

So "talking to your brain" is not a special mode. Your brain simply became one more
tool Claude picks up when a question calls for it.

### The practical upshot

Stop thinking in `gbrain` commands. Once it is wired in:

- Ask Claude questions in plain language; it retrieves and reasons for you.
- Tell it to remember things — "note that we decided X" — and it calls `put_page`.
- The terminal `gbrain` commands are still there for when Claude is not in the loop.

You built a filing cabinet and handed Claude the key.

## What actually makes the answers better

Once Claude is the one writing, the chat model stops being the lever. Two other
things take over, and it is worth being clear about which.

**Your notes are the first lever, and the biggest by far.**

Retrieval can only surface what you actually wrote down. A thin brain gives thin
answers, no matter how strong the models are. So the highest-return habit is simply
capturing — a decision here, a fact there — until the pages exist to be found. A
fuller brain beats a fancier model every time.

**Retrieval quality is the second lever — and that is the embedding model, not the
chat model.**

Keep the split in mind: `search`/`query` find pages with `nomic-embed-text`, and
that choice decides *which* pages Claude ever sees. If the right note is not in the
results, Claude cannot use it — it never reached the prompt. So making Claude
smarter about your brain is really about helping it *find* the right page, which is
the embedding model's job.

`nomic-embed-text` (768 dimensions) is a solid default. When you outgrow it, the
usual step up is **`bge-m3`** (1024 dimensions): multilingual, and noticeably
better at pulling the right page out of a large or messy brain. (`mxbai-embed-large`
is a middle option; `bge-m3` is the one worth knowing.)

The catch: this is not a config toggle. The vector width — 768 for nomic — is baked
into the database column at init time, so moving to a 1024-dimension model means
wiping and re-embedding. Export first so nothing is lost:

```bash
gbrain export --dir ~/brain-backup     # save your pages as markdown
ollama pull bge-m3
mv ~/.gbrain/brain.pglite ~/.gbrain/brain.pglite.bak
gbrain init --pglite --embedding-model ollama:bge-m3 --embedding-dimensions 1024
gbrain import ~/brain-backup           # re-embed every page with the new model
```

When is it worth it? When you have thousands of notes, or you write in more than
one language, or search starts missing things you know are in there. Not on day
one — on day one, `nomic-embed-text` plus the habit of capturing is the whole game.

(gbrain can also add a *reranker* — a second pass that re-orders the top hits for
precision — but that is a later refinement. The embedding model and your notes are
where the real gains live.)

## Teaching Claude to write good notes

If notes are the biggest lever, the obvious next question is: will Claude write good
ones on its own?

Partly. Left to the three-line brain-first protocol, it *will* save things — but the
quality drifts. It might dump a whole conversation into one page, invent
inconsistent slugs, or forget to link anything. Serviceable, not great. It does not
magically write clean notes just because the tool is there.

Three things shape note quality — one you add, two gbrain already does.

**What you add: note conventions in `CLAUDE.md`.**

The same file that tells Claude to search first can tell it *how* to write. Extend
the protocol:

```markdown
## Writing to the brain
When you save a page with put_page:
- One idea per page. Capture the specific decision or fact and the *why* — not a
  whole conversation.
- Namespace the slug by kind: people/<name>, companies/<name>, decisions/<slug>,
  notes/<slug>.
- Set an accurate type (note, person, company, decision) so it fits the schema.
- Link related pages with [[slug]] — a decision links to the people and projects it
  touches.
- Search first and update an existing page instead of creating a duplicate.
- Keep my exact wording for decisions and quotes; don't paraphrase away the specifics.
```

Now the agent files things the way you would, and the brain stays navigable instead
of turning into a pile.

**What gbrain already does #1: it publishes its own filing rules.**

Because `mcp.publish_skills` is on, gbrain exposes `list_skills` / `get_skill` over
MCP — the agent can ask the brain how *it* wants pages filed, and gbrain answers with
its schema conventions. So you are mostly reinforcing habits the brain already
advertises, not inventing them from scratch.

**What gbrain already does #2: it improves the notes over time, on its own.**

gbrain has an overnight maintenance pass — the "dream cycle" (`gbrain dream` once, or
`gbrain autopilot --install` to run it continuously). It dedupes people pages, fixes
broken citations, and wires up links you never made by hand. So even notes you wrote
sloppily get tidied while you sleep. This one *does* use the chat model — so the
dream cycle is exactly where a local qwen, or a bigger model, actually earns its keep
(unlike live retrieval, which never touches it).

So the recipe for good notes: add a few conventions to `CLAUDE.md` for quality as
they are written, lean on gbrain's published rules, and let the dream cycle polish
the pile over time.

## The honest tradeoffs

Real understanding includes the limits, so here they are.

**The simple path is not this one.** The sanctioned, fewer-moving-parts setup is
*local embeddings + cloud synthesis*: keep `nomic-embed-text` local and let a real
Anthropic or OpenAI key write the answer. It is less setup and the prose is
better. I chose full-local on purpose, and paid for it with a workaround and a
smaller model.

**Local retrieval quality is lower.** `nomic-embed-text` is good, but a hosted
embedding model will find relevant notes more reliably on a large, messy brain.
For a few thousand notes you will not notice. For a hundred thousand, you might.

**You are borrowing the OpenRouter namespace machine-wide.** Putting
`OPENROUTER_BASE_URL` and `OPENROUTER_API_KEY=ollama` in `~/.zshrc` sets them for
*every* program in *every* shell. The day you install something that genuinely
uses OpenRouter, it will quietly point at your Ollama with a dummy key and fail in
a confusing way. If that day comes, move these exports out of `~/.zshrc` and
`source env.sh` only when you use gbrain.

**Agentic features run hot.** Pointing `models.default` at a local model means
gbrain's agent loops (`gbrain agent run`, autopilot) run on qwen, which has no
prompt caching — so long loops cost more time. `gbrain doctor` warns about
exactly this and suggests keeping just that one tier on a cloud model. For plain
`think` over your notes, it never comes up.

When should you *not* do this? If you have an API key you are comfortable using,
and you value answer quality over privacy, go local-embeddings-plus-cloud-chat
and skip the openrouter dance entirely. Full-local is for when "nothing leaves
the machine" is the actual requirement, not a nice-to-have.

## The whole thing in three beats

If you remember nothing else, remember the shape:

    Ingestion turns your notes into vectors, once, on your machine.
    PGLite finds the right vectors when you ask, on your machine.
    A local model reads them and writes the answer, on your machine.

One embedding model to remember. One chat model to explain. One file to hold it
all. And a log full of `127.0.0.1` to prove it.

## Appendix: every command

The whole surface of `gbrain 0.42.53.0`, grouped the way `gbrain --help` groups
it. Prefix each with `gbrain`; run `gbrain <command> --help` for details. The ones
you actually reach for day-to-day are marked ★.

**Setup & health**

```text
init [--pglite|--supabase|--url]      create a brain (PGLite = local, no server)
migrate --to <supabase|pglite>        move a brain between engines
upgrade                               self-update gbrain
check-update [--json]                 check for a new version
doctor [--json] [--fast]           ★  health check (embeddings, pgvector, skills…)
integrations [subcommand]             manage integration recipes (senses + reflexes)
```

**Get content in**

```text
capture [content] [--file P] [--stdin]  ★ single entrypoint to add content (→ inbox/)
import <dir> [--no-embed]               ★ bulk-import a markdown directory
put <slug> [< file.md]                    write/update one page
sync [--repo P] [--watch] [--install-cron] git repo → brain, incremental
embed [<slug>|--all|--stale]              (re)generate embeddings
```

**Read, search, ask**

```text
search <query>                     ★  keyword search — ranked pages, no LLM
query <question> [--no-expand]     ★  hybrid search, meaning + keywords (alias: ask)
think <question>                   ★  synthesized, cited answer (uses the LLM)
get <slug>                            read one page
list [--type T] [--tag T] [-n N]      list pages
```

**Pages & versions**

```text
delete <slug>                         delete a page
history <slug>                        page version history
revert <slug> <version-id>            revert to a prior version
```

**The graph: links, tags, timeline**

```text
link <from> <to> [--link-type T]      create a typed link (alias: link-add)
unlink <from> <to>                    remove a link (alias: link-rm)
link-sources                          list link provenances + edge counts
backlinks <slug>                      incoming links
graph <slug> [--depth N]              traverse the link graph
graph-query <slug> [--type T] [--direction in|out|both]  edge-filtered traversal
tags <slug> / tag <slug> <t> / untag <slug> <t>          list / add / remove tags
timeline [<slug>]                     view timeline
timeline-add <slug> <date> <text>     add a timeline entry
```

**Ideate (brainstorming over your brain)**

```text
brainstorm <question> [--json]        bisociation idea generator (hybrid + far-set + judge)
lsd <question> [--json]               Lateral Synaptic Drift — far-from-obvious ideas
```

**Code indexing (for a synced codebase)**

```text
code-def <symbol> [--lang l]          find a symbol's definition
code-refs <symbol> [--lang l]         find references to a symbol
code-callers <symbol>                 who calls this symbol
code-callees <symbol>                 what this symbol calls
query <q> --lang <l> | --symbol-kind <k>  filter hybrid search by language / symbol type
reconcile-links [--dry-run]           recompute doc↔impl edges
reindex-code [--source id] [--yes]    reindex code pages
sync --strategy code                  sync code files into the brain
```

**Multiple sources / repos**

```text
sources list                          show registered sources
sources add <id> --path <p>           register a source
sources remove <id>                   remove a source + its pages
sync --all | --source <id>            sync all sources / one source
```

**Export & files**

```text
export [--dir ./out/]                 export the brain to markdown
files list [slug]                     list stored files
files upload <file> --page <slug>     attach a file to a page
files upload-raw <file> --page <s>    smart upload (size routing + redirect)
files signed-url <path>               1-hour signed URL
files sync <dir> / files verify       bulk upload / verify uploads
```

**Maintenance & tools**

```text
extract <links|timeline|all>          extract links/timeline (idempotent)
lint <dir|file> [--fix]               catch LLM artifacts, bad frontmatter, placeholder dates
orphans [--json] [--count]            pages with no inbound links
check-backlinks <check|fix> [dir]     find/fix missing backlinks
salience [--days N] [--kind P]        pages ranked by emotional + activity salience
anomalies [--since D] [--sigma N]     cohort-based statistical anomalies
transcripts recent [--days N]         recent raw local transcripts
dream [--dry-run] [--json]            run the overnight maintenance cycle once
publish <page.md> [--password]        shareable HTML (strips private data, optional AES-256)
report --type <name> --content ...    save a timestamped report to the brain
check-resolvable [--json] [--fix]     validate the skill tree (reachability/MECE/DRY)
```

**Background jobs (Minions — Postgres/Supabase only)**

```text
jobs submit <name> [--params JSON]    submit a background job [--follow]
jobs list | get <id> | cancel <id> | retry <id>   manage jobs
jobs prune [--older-than 30d] | stats | work      clean / dashboard / worker daemon
```

**Serve & connect an agent**

```text
serve                              ★  MCP server over stdio (what `claude mcp add` runs)
serve --http [--port N]               HTTP MCP server with OAuth 2.1
connect <mcp-url> --token <t> [--install]  wire this machine to a remote gbrain
watch [--json]                        pipe conversation turns in, stream brain pages out
call <tool> '<json>'                  raw tool invocation
--tools-json                          tool discovery (JSON)
```

**Admin**

```text
stats                                 brain statistics
health                                brain health dashboard
features [--json] [--auto-fix]        scan usage, recommend unused features
autopilot [--repo] [--interval N]     self-maintaining brain daemon
config [show|get|set] <key> [val]  ★  brain config (e.g. config set chat_model …)
storage status [--json]               storage tier status and health
version                               version info
```

`think` is the odd one out: it is not printed in `gbrain --help`'s summary, but it
is real and it is the command that writes a synthesized, cited answer. `search`,
`query`, and `ask` return ranked pages; `think` writes the prose.
