# Step 2 — Pull the models

gbrain needs two models, and they do two completely different jobs. This trips
people up, so it is worth being clear before you download anything.

## Two models, two jobs

**The embedding model turns text into numbers.**

You give it a sentence.

It gives back a list of 768 numbers.

That list is called a vector. Similar sentences get similar vectors. That is
the whole trick that makes search work later.

**The generation model turns context into an answer.**

You give it your question plus the notes that matched.

It writes prose back.

These are not interchangeable. An embedding model cannot write you a paragraph.
A chat model can produce an embedding, but it is huge and slow for a job that
runs on every single note. So gbrain uses one of each.

```
"what did I decide about pricing?"
        ↓
  nomic-embed-text   → [0.02, -0.5, 0.1, ... ]   (768 numbers)   ← embedding model
        ↓
  find the closest note vectors in the database
        ↓
  qwen2.5:14b        → "You decided to raise the base tier to..."  ← generation model
```

## What we ran

```bash
ollama pull nomic-embed-text     # embeddings, 768 dimensions, ~274 MB
ollama pull qwen2.5:14b          # generation, ~9 GB
```

## Pulling means downloading, once

`ollama pull` copies the model weights to `~/.ollama/models` on your disk.

It happens one time.

After that the model is on your machine forever, and loads from local disk. No
download on the next run, no network at query time.

## Why these two

- **nomic-embed-text** — 768 dimensions, small, fast. It is the default gbrain
  expects for Ollama, so its output width (768) already matches what the brain
  will be told to store. Picking a model whose width matches the brain matters,
  because the number 768 gets baked into the database in the next step.
- **qwen2.5:14b** — big enough to write good synthesis with citations, small
  enough to sit comfortably in 32 GB with room to spare on Apple Silicon.

## Where it runs, what gets stored

- Runs: your machine's GPU, through Ollama.
- Stored: the weights, in `~/.ollama/models`. About 274 MB + 9 GB.
- Your notes are **not** here yet. This step only stages the two models.

## Check it worked

```bash
ollama list
# NAME                       SIZE
# nomic-embed-text:latest    274 MB
# qwen2.5:14b                 9.0 GB
```

Two models listed means both jobs are covered: one to remember, one to explain.
