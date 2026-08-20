#!/bin/bash
# Reproduce the throughput numbers in docs/oracle-feasibility.md
set -euo pipefail
source "$(dirname "$0")/env.sh"
exec "$LLAMA_BIN/llama-bench" -m "$MODEL" -t "$(nproc)" -p 128 -n 64
