# Using gbrain: locally and globally

You installed it. Now what do you actually type?

There are two ways to use gbrain, and one rule that governs both.

- **Locally** — you talk to it directly, from the terminal (`gbrain ...`).
- **Globally** — you wire it into your coding agent, and the agent talks to it
  for you while you work.

The rule underneath both: **gbrain only saves what it is explicitly told to
save.** Nothing is captured automatically. Not your terminal, not your chats.
Something lands in the brain only when a write command runs or an agent calls a
write tool.

## The mental model: in, and out

Everything you do is one of two things: putting knowledge *in*, or getting it
*out*.

```
   PUT IN                          GET OUT
   capture / import / put / sync   search / query / think / get
        ↓                                    ↑
              ~/.gbrain/brain.pglite
              (your whole brain, one file)
```

## Locally (the CLI)

### Putting things in

```bash
# One thought, right now — the fastest way to build the habit:
gbrain capture "Decided to run gbrain fully local: Ollama + PGLite, no cloud."

# A folder of markdown you already have:
gbrain import ~/notes/

# A specific page, written from a file or stdin:
gbrain put meetings/acme-kickoff < notes.md

# A whole git repo (great for a codebase):
gbrain sync --repo ~/code/myproject
```

Each of these creates or updates pages, embeds them, and stores them. That is the
only way text enters the brain.

### Getting things out

There are three retrieval commands, and they are not the same:

```bash
gbrain search "pricing"                 # ranked pages, keyword match — fast, no LLM
gbrain query  "why was the price raised?"  # hybrid (meaning + keywords), ranked pages
gbrain think  "why was the price raised?"  # a written, cited answer — uses the LLM
```

The important practical difference, verified on this setup:

- `search` and `query` **only use the embedding model.** They hand you the
  matching pages. Fast, and they work even if the chat model is not wired up.
- `think` is the one that **calls qwen2.5:14b** to synthesize a paragraph with
  citations and gap analysis. It is the only retrieval command that needs the
  generation model.

Round it out with:

```bash
gbrain get pricing-decision     # read one page
gbrain list                     # see everything in the brain
gbrain backlinks pricing-decision   # what links to this page
```

## Globally (wired into your coding agent)

This is where it gets powerful: your agent (Claude Code, Codex, Cursor) can call
the brain itself, over MCP.

### Wire it up

```bash
claude mcp add gbrain \
  -e OPENROUTER_BASE_URL=http://localhost:11434/v1 \
  -e OPENROUTER_API_KEY=ollama \
  -e GBRAIN_QUERY_EMBED_TIMEOUT_MS=30000 \
  -- gbrain serve
```

The agent spawns `gbrain serve` as a subprocess and gets tools like `search`,
`query`, `put_page`, and `find_experts`.

**Why the `-e` flags matter on this local setup.** A coding agent launches
`gbrain serve` with a clean environment — it does *not* read your `~/.zshrc`. So
if you skip the env flags, brain *search* still works (embeddings need no env),
but *synthesis* (`query`/`think` over MCP) falls back to "no LLM available." The
`-e` flags hand the local-model route straight to the subprocess.

### Teach the agent to use it

Paste this into your project's `CLAUDE.md` (or `AGENTS.md`):

```markdown
## Brain-first protocol
You have a knowledge brain over MCP. Before answering about people, companies,
decisions, or past context: (1) search/query the brain first; (2) write new
decisions or ideas back with put_page; (3) cite the page you used.
```

Now the four habits that make it worth it:

- **Brain-first lookup** — the agent searches before it asks you.
- **Ambient capture** — tell it "save decisions as we work"; the brain fills as a
  side effect.
- **Briefing** — "what do I need to know before X?" pulls your own context.
- **whoknows** — "who have I met who's done Y?" ranks people in your brain.

### The gstack shortcut

You have two [gstack](https://github.com/garrytan/gstack) skills that automate
all of this:

- `/setup-gbrain` — installs/detects gbrain, registers the MCP, and writes the
  brain-first routing into `CLAUDE.md`. It also sets a per-repo trust policy.
- `/sync-gbrain` — indexes the current code repo into the brain, so
  `gbrain search` and `gbrain code-def` / `code-refs` work semantically across
  your codebase, and adds search guidance to `CLAUDE.md`.

## So, is my chat with the agent saved?

Only if the agent writes it. Connecting over MCP does not record the
conversation. The agent saves something when it calls `put_page` — which, with
the brain-first protocol above, it does for decisions and new ideas, and nothing
else. You stay in control of what your brain remembers.

## Where your data lives

One file: `~/.gbrain/brain.pglite`. Back it up, copy it to another Mac, or delete
it to start over. That folder is your entire brain.

## Full command reference

Every command `gbrain 0.42.53.0` exposes, grouped the way `gbrain --help` groups
them. Prefix each with `gbrain`, and run `gbrain <command> --help` for the details
of any one. The handful you will actually use day-to-day are marked ★.

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

> Note: `think` is not printed in `gbrain --help`'s summary, but it is a real,
> working command — it is the one that produces a synthesized answer with
> citations. `search`, `query`, and `ask` return ranked pages; `think` writes prose.
