# What gbrain is, and why you would use it

Start here, before any install commands.

## What it is

gbrain is a place to put everything you know, that can then *answer questions*
about it.

Not a note app. Not a chatbot. Something in between:

- You feed it notes — decisions, people, meetings, ideas, whole documents.
- It stores each one as a **page**.
- When you ask a question, it finds the relevant pages and writes you an answer
  that **cites** them.

That is the one-line version. A searchable memory that explains itself.

## Why not just use search, or ChatGPT?

Because both fail in opposite ways.

**Search** gives you a list of documents and makes you do the reading. Ten links,
and the answer is somewhere inside three of them.

**ChatGPT** writes you a confident answer, but it has never seen your notes. Ask
it "what did *we* decide about pricing?" and it guesses.

gbrain sits in the gap. It reads *your* pages and answers from them:

```
you:     "Why was the base tier price raised?"
gbrain:  "Raised from $19 to $29 because support costs per seat grew and the
          $19 tier was unprofitable below 50 seats [pricing-decision]."
```

Two things there that neither search nor a generic chatbot gives you:

- The answer is built from your own note, not the internet.
- It names the page it used, so you can trust and verify it.

And when it does *not* know, it says so — that is the "gap analysis" you will see
in `gbrain think` output. An honest "I don't have that" beats a confident wrong
answer.

## What is going on under the hood (the short version)

Three ideas, and you have already met all of them in this repo:

- **Pages** — each note is one page, with a slug like `pricing-decision`.
- **Embeddings** — each page is also stored as a list of numbers, so gbrain can
  find pages by *meaning*, not just keywords. ("price bump" finds a note that
  said "raise the tier".)
- **Links** — pages connect to each other (a decision links to the people and
  projects it touches), so answers can pull in related context.

## Why you would actually use it

- **Your context stops evaporating.** The decision you made in March is still
  answerable in September, in your words, with the reasoning attached.
- **You ask across everything at once.** Not "which file was that in" — just ask.
- **It gives your coding agent a memory.** Wired into Claude Code (see
  `08-using-gbrain.md`), the agent stops asking you things it could look up, and
  writes new decisions back as you work.
- **In this setup, it is entirely yours.** Local models, a local file, no cloud.

## When it is not worth it

If you never put anything in, it stays empty and answers nothing. An empty brain
on day one feels broken — that is expected.

gbrain earns its keep once capturing becomes a habit: a sentence here, a decision
there, a folder of notes imported once. By the second week it knows things you
had forgotten. Before that, it is just an install.

Next: [`01-prerequisites.md`](01-prerequisites.md) to build it, or
[`08-using-gbrain.md`](08-using-gbrain.md) to see how to use it once it runs.
