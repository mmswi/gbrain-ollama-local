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
