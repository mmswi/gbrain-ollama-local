# Step 7 — Make it survive a reboot

Everything works, but only *in the shell we set up*. Close the terminal and two
things vanish: the Ollama daemon (started by hand) and the four env vars (only in
`env.sh`). This step makes both permanent, and it helps to know what each one
produces.

## Step 1 — Ollama as a background service

```bash
brew services start ollama
```

This writes a **launchd agent** — a file at
`~/Library/LaunchAgents/homebrew.mxcl.ollama.plist` — and registers it with macOS.

launchd is the part of macOS that starts programs at login and restarts them if
they crash.

What it produces:

- A daemon that starts at login and relaunches itself if it dies.
- A log at `/opt/homebrew/var/log/ollama.log`.
- No more typing `ollama serve`.

```bash
brew services list
# ollama   started   ~/Library/LaunchAgents/homebrew.mxcl.ollama.plist
```

## Step 2 — load the env in every shell

The four exports live in [`../env.sh`](../env.sh). Add one line to `~/.zshrc`
(the file your shell runs at startup):

```bash
source ~/Projects/gbrain-ollama/env.sh
```

What it produces:

- `OPENROUTER_BASE_URL`, `OPENROUTER_API_KEY`, `GBRAIN_QUERY_EMBED_TIMEOUT_MS`,
  and `OLLAMA_KEEP_ALIVE` set in every interactive shell.
- gbrain reads them from the environment, so `gbrain think` finds the local route
  with nothing sourced by hand.

## The test that proves both

Open a brand-new terminal. Type only:

```bash
gbrain think "What did we decide about pricing and why?"
```

Then look at `/opt/homebrew/var/log/ollama.log`. Two `127.0.0.1` lines and a cited
answer means a fresh terminal is fully wired, fully local.

## One honest caveat

The launchd daemon starts with a clean environment — it does not read `env.sh` —
so `OLLAMA_KEEP_ALIVE` from your shell does not reach it. The service falls back
to unloading an idle model after a few minutes.

That is exactly why `GBRAIN_QUERY_EMBED_TIMEOUT_MS=30000` matters: it lets the
query embedding wait out the occasional cold reload instead of failing.
