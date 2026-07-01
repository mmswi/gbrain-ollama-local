# Step 1 — Prerequisites

Before gbrain can do anything, two things have to exist on your machine:

- **bun** — the runtime gbrain is installed and run with.
- **Ollama** — the local model server that will run both the embeddings and the LLM.

That is the whole step. Get both on the machine, then start Ollama.

## What we ran

```bash
# bun was already here (1.3.5). If you don't have it:
curl -fsSL https://bun.sh/install | bash

brew install ollama          # installs the ollama binary, ~48 MB
```

## Ollama is a server, not a library

This is the part people miss.

Ollama does not run inside gbrain.

It runs as a **separate background process** that listens on a port.

```bash
ollama serve                 # listens on http://localhost:11434
```

gbrain talks to it over HTTP, on `http://localhost:11434/v1`.

Same way it would talk to OpenAI.

Except the address is your own laptop.

So the flow, from the very start, looks like this:

```
gbrain (a CLI)
   ↓  HTTP request to localhost:11434
Ollama (a running daemon)
   ↓
the model does the work on your GPU
```

Nothing leaves the machine. There is no API key, because there is nobody to
authenticate to. The server is you.

## Where things run

- `bun` and `gbrain`: your machine.
- `ollama serve`: your machine, a separate process.
- The models: your machine's GPU (Apple Silicon, via Metal/MLX).

## What gets stored

Nothing yet. This step only installs binaries and starts a daemon. The models
and your notes come later.

## Check it worked

```bash
ollama --version                       # client version prints
curl -s http://localhost:11434/api/tags # daemon answers (empty list is fine)
```

If the `curl` returns JSON, the daemon is up and gbrain will be able to reach it.
