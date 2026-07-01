# explanatory-docs

Short docs that explain *how each piece works* — where the work runs, what data
moves, what gets stored — not just the command to copy. The numbered setup docs
each line up with one commit in this repo.

**Read these first:**

| Doc | What |
| --- | --- |
| `00-what-is-gbrain.md` | What gbrain is and why you would use it |
| `08-using-gbrain.md` | How to use it, locally (CLI) and globally (agent/gstack) |

**The setup, step by step:**

| Doc | Step |
| --- | --- |
| `01-prerequisites.md` | Install Ollama + bun, start the daemon |
| `02-pull-models.md` | Pull the embedding model and the LLM |
| `03-install-gbrain.md` | Install the gbrain CLI |
| `04-init-brain.md` | Create the local PGLite brain on Ollama embeddings |
| `05-generation-model.md` | Point generation at the local LLM |
| `06-verify.md` | Prove it runs with no external calls |
| `07-persistence.md` | Make the daemon + env survive a reboot |
