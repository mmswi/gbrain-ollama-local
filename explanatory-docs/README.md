# explanatory-docs

One short doc per setup step. Each explains *how the step works* — where the
work runs, what data moves, what gets stored — not just the command to copy.

Each doc lines up with one commit in this repo.

| Doc | Step |
| --- | --- |
| `01-prerequisites.md` | Install Ollama + bun, start the daemon |
| `02-pull-models.md` | Pull the embedding model and the LLM |
| `03-install-gbrain.md` | Install the gbrain CLI |
| `04-init-brain.md` | Create the local PGLite brain on Ollama embeddings |
| `05-generation-model.md` | Point generation at the local LLM |
| `06-verify.md` | Prove it runs with no external calls |
| `07-persistence.md` | Make the daemon + env survive a reboot |
