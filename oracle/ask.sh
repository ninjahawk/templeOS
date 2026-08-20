#!/bin/bash
# One-shot generation.  usage: ./ask.sh "prompt" [n_tokens]
set -euo pipefail
source "$(dirname "$0")/env.sh"
PROMPT="${1:?usage: ./ask.sh \"prompt\" [n_tokens]}"
N="${2:-80}"
exec "$LLAMA_BIN/llama-cli" -m "$MODEL" \
  -t "$(nproc)" -n "$N" -c 2048 --temp 0.8 \
  -no-cnv --no-warmup -st -p "$PROMPT" 2>/dev/null
