# Step 5 — Wire the generation LLM

Embeddings are local. Now we need the *answer-writing* model to be local too.

The obvious move is to mirror what worked for embeddings. It does not work. Walk
through why, because the reason is the whole point of this step.

## The bad version (what you would try first)

Embeddings used `ollama:nomic-embed-text`. So generation should be
`ollama:qwen2.5:14b`, right?

```bash
gbrain config set chat_model ollama:qwen2.5:14b
gbrain think "Why was the price raised?"
```

Here is what you get back:

```
(no LLM available — set ANTHROPIC_API_KEY or pass `client`)
Model: ollama:qwen2.5:14b | Pages: 2 | Warnings: NO_ANTHROPIC_API_KEY
```

Read that carefully. It *knows* the model is `ollama:qwen2.5:14b`. It found 2
pages. Then it gave up and asked for an Anthropic key.

The retrieval ran locally. The synthesis refused.

## Why it refuses: recipes and touchpoints

gbrain talks to every provider through a **recipe**.

A recipe is a small description of one provider: its URL, how it authenticates,
and which **touchpoints** it supports.

A touchpoint is a job type. There are three: `embedding`, `chat`, `reranker`.

Now look at the actual Ollama recipe inside gbrain:

```
ollama recipe
  touchpoints:
    embedding:  ✓   (nomic-embed-text, mxbai-embed-large, all-minilm)
    chat:       ✗   (not declared)
```

That is the entire explanation.

The Ollama recipe declares `embedding` and nothing else. So when you ask gbrain
to *chat* with Ollama, it checks the recipe, sees no `chat` touchpoint, and
falls back to its built-in default — which is a cloud model that needs a key.

This is not your mistake. It is a known, open gap in gbrain (its own
`COMMUNITY_IDEAS.md` lists "local-first chat parity" and "litellm proxy unusable
for chat" as open issues). Ollama is wired for embeddings only. For now.

## The fix: borrow a recipe that *does* have chat

We need a recipe that has a `chat` touchpoint **and** lets us change its URL to
point at Ollama.

Of all the chat-capable recipes, only the OpenAI-compatible ones can be
repointed by an environment variable. `openrouter` is one of them.

So the trick is:

```
openrouter recipe  (has chat ✓, speaks the OpenAI API)
        ↓  we change its base URL
http://localhost:11434/v1   (Ollama's OpenAI-compatible endpoint)
```

Ollama already speaks the OpenAI API. So gbrain thinks it is calling OpenRouter,
and the bytes actually land on Ollama, on your laptop.

## What we ran

```bash
export OPENROUTER_BASE_URL=http://localhost:11434/v1   # send openrouter calls to Ollama
export OPENROUTER_API_KEY=ollama                       # dummy; Ollama ignores auth headers
gbrain config set chat_model     openrouter:qwen2.5:14b
gbrain config set models.default openrouter:qwen2.5:14b
```

- `chat_model` is what `think` uses to write the answer.
- `models.default` is the base every model "tier" falls back to, so agent tasks
  use the local model too.
- The dummy key exists only because gbrain checks that *a* key is present before
  it will try. Ollama throws the key away.

## Two gotchas we hit (and fixed)

**The base URL has to be an environment variable, not config.**

`gbrain config set provider_base_urls.openrouter ...` looks like it works, and
`config get` even reads it back. But the gateway never reads that value — it
reads `OPENROUTER_BASE_URL` from the environment. So the base URL lives in
`env.sh`, not in the brain config. (This is the file-plane vs DB-plane split;
some keys persist to the config file, some to the database, and a few are
accepted but read by nobody.)

**A cold LLM can starve the query embedding.**

The first question after a restart timed out its embedding step at 6 seconds
(Ollama was busy loading the 9 GB model) and the answer came back empty. Fix:

```bash
export GBRAIN_QUERY_EMBED_TIMEOUT_MS=30000   # give the embed room to wait
export OLLAMA_KEEP_ALIVE=30m                  # keep the model warm so it rarely reloads
```

All four exports live in [`../env.sh`](../env.sh).

## Where it runs, what gets stored

- Runs: your machine. Retrieval and synthesis both hit `localhost:11434`.
- Stored: `chat_model` and `models.default` in the brain (via `config set`). The
  URL and key are not stored — they are environment variables.
- Leaves the machine: nothing.

## The honest tradeoff

The simple, sanctioned setup is **local embeddings + cloud synthesis**: keep
`nomic-embed-text` local and let a real Anthropic or OpenAI key write the answer.
Fewer moving parts, better prose.

We chose full-local on purpose — no key, nothing leaves the laptop — and paid for
it with a workaround and a smaller model.

One thing stays cloud-shaped even so: pointing `models.default` at a 14B local
model means gbrain's agentic features (`gbrain agent run`, autopilot) run on
qwen, which does not tool-loop as well as a frontier model. `gbrain doctor` warns
about exactly this. For plain `think` over your notes, it is a non-issue.
