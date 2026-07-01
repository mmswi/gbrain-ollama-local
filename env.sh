# gbrain-ollama local setup — environment
# Source this in each shell that runs gbrain:  source /path/to/gbrain-ollama/env.sh
# (or add that line to ~/.zshrc to make it permanent).
#
# Why these exist: gbrain's native `ollama` recipe is embeddings-only (no chat
# touchpoint), so `chat_model: ollama:...` degrades to "no LLM available".
# Generation is instead routed through the OpenAI-compatible `openrouter` recipe,
# whose base URL we repoint at Ollama's local /v1 endpoint.

export OPENROUTER_BASE_URL=http://localhost:11434/v1   # send "openrouter" calls to Ollama
export OPENROUTER_API_KEY=ollama                       # dummy; Ollama ignores auth headers
export GBRAIN_QUERY_EMBED_TIMEOUT_MS=30000             # let the query-embed wait out LLM cold-load
export OLLAMA_KEEP_ALIVE=30m                           # keep models warm between calls
