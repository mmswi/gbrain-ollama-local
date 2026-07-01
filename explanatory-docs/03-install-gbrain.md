# Step 3 — Install the gbrain CLI

Now we install gbrain itself.

One thing to keep straight: gbrain is not a model and not a database. It is the
**glue**. It takes your commands, calls Ollama for the AI work, and reads and
writes the database for storage. On its own it holds neither.

```
        gbrain  (the CLI you type)
        /            \
   Ollama            PGLite
 (the models)     (the storage)
```

## What we ran

```bash
bun install -g github:garrytan/gbrain
```

`-g` means global: it puts a `gbrain` command on your PATH, so you can run it
from any folder. The package is fetched straight from GitHub and lands in bun's
global folder (`~/.bun/install/global/node_modules/gbrain`), with a `gbrain`
symlink into `~/.bun/bin`.

## Check it worked

```bash
gbrain --version
# gbrain 0.42.53.0
```

## It is installed, but there is no brain yet

This is the important part.

Having `gbrain` on your PATH does not mean you have a brain.

Run a real command now and it tells you so:

```bash
gbrain doctor
# No brain configured. Run: gbrain init
```

A "brain" is a database plus a small config file that says which models to use.
Neither exists yet. The binary is on the machine; it just has nothing to point
at.

That is the next step: `gbrain init`.

## Where it runs, what gets stored

- Runs: your machine.
- Stored: the package files under `~/.bun/`. No models, no notes, no config yet.
- Talks to: nothing, until you give it a brain.
