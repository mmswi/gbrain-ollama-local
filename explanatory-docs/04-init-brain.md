# Step 4 — Initialize the brain

This is the step that creates an actual brain: a place to store notes, and a
record of which models to use.

## What we ran

```bash
gbrain init --pglite \
  --embedding-model ollama:nomic-embed-text \
  --embedding-dimensions 768
```

Three decisions are packed into that one line.

## `--pglite`: the database is a file, not a server

Normally Postgres is a server you install, start, and connect to.

PGLite is Postgres compiled to run **inside gbrain**, storing everything in a
single folder.

```bash
~/.gbrain/brain.pglite     # your entire brain lives here
```

No server to start. No port. No password. You could copy that folder to another
Mac and it would just work. This is why PGLite is the try-first option: zero
moving parts.

## `--embedding-model ollama:nomic-embed-text`: read this as `provider:model`

gbrain reads the part before the **first** colon as the provider, and the rest
as the model name.

```
ollama : nomic-embed-text
  │            │
provider     model
```

So this says: "embed with the `nomic-embed-text` model, served by Ollama."
gbrain will send text to `http://localhost:11434/v1` to get vectors back.

(The first-colon rule is why a name like `ollama:qwen2.5:14b` still works later.
Provider is `ollama`; the model is the whole `qwen2.5:14b`, colon and all.)

## `--embedding-dimensions 768`: this number gets baked into the database

An embedding is a fixed-length list of numbers. nomic-embed-text always returns
768 of them.

gbrain sizes the database's vector column to exactly 768 at init time.

That size is now fixed. Every vector stored from here on must be 768 wide. If
you later switch to a model that outputs 1024 numbers, the old column no longer
fits, and you have to re-init and re-embed. So the model and the dimensions have
to agree, and they do: 768 and 768.

## What got created

```bash
cat ~/.gbrain/config.json
```

```json
{
  "engine": "pglite",
  "database_path": "/Users/you/.gbrain/brain.pglite",
  "embedding_model": "ollama:nomic-embed-text",
  "embedding_dimensions": 768,
  "chat_model": null
}
```

Two things now exist:

- `config.json` — the small file that says which engine and which models.
- `brain.pglite` — the database itself, empty, with a 768-wide vector column ready.

## One thing is deliberately still missing

Look at the last line: `"chat_model": null`.

Embeddings are local now. Generation is not.

When `chat_model` is null, gbrain falls back to its built-in default, which is a
**cloud** model (`anthropic:claude-sonnet-4-6`) and would need an API key. So
right now the brain can store and search locally, but asking it to *write an
answer* would try to phone a cloud.

That is the next step: point generation at the local LLM too.
