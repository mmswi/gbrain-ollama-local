# gbrain, fully local on Apple Silicon

A working log of installing [gbrain](https://github.com/garrytan/gbrain) so it runs
with **zero external API calls**: Ollama serves both the embeddings and the
generation model, and PGLite stores everything in a local file. No OpenAI key,
no Anthropic key, no cloud Postgres.

Built and verified on an **Apple M5, 32 GB**.

## What is gbrain?

gbrain is a searchable memory that answers questions about your own notes — and
cites the note it used. Not a note app, not a generic chatbot: you feed it
decisions, people, meetings, and documents, and later ask "what did we decide
about X?" and get a cited answer built from *your* pages, not the internet. When
it doesn't know, it says so.

Why bother: your context stops evaporating, you ask across everything at once,
and (wired into a coding agent) it gives that agent a memory so it stops
re-asking what it could look up. Full "what it is / why / when it's not worth it"
in [`explanatory-docs/00-what-is-gbrain.md`](explanatory-docs/00-what-is-gbrain.md);
how to actually use it in
[`explanatory-docs/08-using-gbrain.md`](explanatory-docs/08-using-gbrain.md).

## What each piece does

```
Your notes (markdown)
      ↓
Ollama  nomic-embed-text   → turns text into 768-number vectors   (embeddings)
      ↓
PGLite  (~/.gbrain/pglite) → stores pages + vectors in one file   (memory)
      ↓
Ollama  qwen2.5:14b        → reads the top matches, writes the answer (generation)
```

- **Ollama** runs the models locally on `http://localhost:11434`.
- **PGLite** is Postgres compiled to run in-process, so there is no database server to manage.
- **gbrain** is the CLI that wires them together and does the search + synthesis.

> **The one gotcha:** gbrain's native `ollama` provider is *embeddings-only* — it
> has no chat capability — so `chat_model: ollama:...` silently degrades to
> "no LLM available". Generation is routed through gbrain's OpenAI-compatible
> `openrouter` recipe, with its base URL repointed at Ollama. See
> [`explanatory-docs/05-generation-model.md`](explanatory-docs/05-generation-model.md).

## How this repo is organized

- [`explanatory-docs/`](explanatory-docs/) — one short doc per setup step, explaining
  *how it works*, not just what to type. Each doc matches one commit.
- `blog-post.md` — the full write-up.

## Reproduce it

The setup is six steps. Full commands and the reasoning behind each are in
`explanatory-docs/`, but the short version:

```bash
# 1. Prerequisites
brew install ollama
ollama serve                     # daemon on :11434

# 2. Models
ollama pull nomic-embed-text     # embeddings, 768d
ollama pull qwen2.5:14b          # generation

# 3. Install gbrain
bun install -g github:garrytan/gbrain

# 4. Init a local brain on Ollama embeddings
gbrain init --pglite \
  --embedding-model ollama:nomic-embed-text \
  --embedding-dimensions 768

# 5. Route generation through the openrouter recipe, pointed at Ollama.
#    (chat_model: ollama:... does NOT work — the ollama recipe has no chat.)
export OPENROUTER_BASE_URL=http://localhost:11434/v1   # send openrouter calls to Ollama
export OPENROUTER_API_KEY=ollama                       # dummy; Ollama ignores auth
gbrain config set chat_model     openrouter:qwen2.5:14b
gbrain config set models.default openrouter:qwen2.5:14b

# 6. Verify — fully local (Ollama serves both /v1/embeddings and /v1/chat/completions)
gbrain providers test --model ollama:nomic-embed-text
gbrain import ~/notes
gbrain think "..."
```

The four `export`s live in [`env.sh`](env.sh) — `source` it in each shell (or add
that line to `~/.zshrc`). Base URL and key must be env vars: gbrain reads
`OPENROUTER_BASE_URL` from the environment, and `provider_base_urls.*` set via
`gbrain config set` is a no-op (it writes a plane the gateway never reads).
