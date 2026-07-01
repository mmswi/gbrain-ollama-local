# Step 6 — Verify it is actually local

"Fully local" is a claim. Do not trust it — watch the traffic.

The whole setup is worth nothing if some step quietly phones a cloud. So the real
test is not "does gbrain answer" — it is "did every model call land on
`localhost`, and zero calls leave the machine."

Three checks, cheapest first.

## Check 1 — the embedding provider answers

```bash
gbrain providers test --model ollama:nomic-embed-text
```

```
Probing embedding provider...
  ✓ 366ms, 768 dims
All probes green.
```

768 dimensions, served locally, in a third of a second. This is the model that
runs on every note and every query.

## Check 2 — doctor agrees, and the one warning is expected

```bash
gbrain doctor
```

The lines that matter:

```
[OK]   embedding_provider: ollama:nomic-embed-text ✓ 37ms, 768 dims, DB aligned
[OK]   embedding_width_consistency: Schema width (768d) matches gateway embedding_dimensions
[WARN] subagent_capability: models.default is "openrouter:qwen2.5:14b" —
       provider does not support prompt caching. ... use an Anthropic model for
       the subagent tier.
```

Two greens, one yellow. The yellow is not a failure — it is doctor telling you
that a local model has no prompt caching, so *agentic* loops cost more. Plain
`think` does not care. This warning is the expected price of going full-local.

## Check 3 — the proof: watch Ollama serve both calls

This is the one that counts. Ask a real question, and tail Ollama's log at the
same time.

```bash
gbrain import ~/notes
gbrain think "What did we decide about pricing and why?"
```

The answer, with a citation:

```
We decided to raise the base tier from $19 to $29/month starting July because
support costs per seat increased and the $19 tier was unprofitable below 50
seats [pricing-decision]. Existing customers are grandfathered at $19 for 12
months.
Model: openrouter:qwen2.5:14b | Pages: 2 | Citations: 1
```

And, at the same moment, in Ollama's own log:

```
200  25ms     POST  /v1/embeddings         ← the question got turned into a vector
200  10.6s    POST  /v1/chat/completions   ← qwen wrote the answer
```

That is the whole system, on one machine:

```
your question
   ↓  POST /v1/embeddings        (nomic-embed-text, 25ms)
find the matching notes in PGLite
   ↓  POST /v1/chat/completions  (qwen2.5:14b, 10.6s)
a cited answer
```

Two local requests. No Anthropic. No OpenAI. No key that reaches the internet.

## What "done" looks like

- `providers test` is green.
- `doctor` shows the embedding provider OK and only the expected subagent warning.
- Every `think` produces two `localhost:11434` log lines and nothing else.

If all three hold, the brain is yours, on your disk, answered by your GPU.
