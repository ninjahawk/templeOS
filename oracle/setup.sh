#!/bin/bash
# Build llama.cpp and fetch a 0.5B model for CPU-only inference.
# No GPU required. Takes ~5 min (build) + ~1 min (download) on 4 cores.
set -euo pipefail
source "$(dirname "$0")/env.sh"

mkdir -p "$ORACLE_DIR"
cd "$ORACLE_DIR"

if ! command -v cmake >/dev/null || ! command -v g++ >/dev/null; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -qq && apt-get install -y -qq build-essential cmake git curl
fi

if [ ! -d llama.cpp ]; then
  echo ">> cloning llama.cpp"
  git clone --depth 1 https://github.com/ggml-org/llama.cpp
fi

if [ ! -x "$LLAMA_BIN/llama-cli" ]; then
  echo ">> building (CPU backend, native ISA -- this box has AVX-512)"
  cd llama.cpp
  cmake -B build -DGGML_NATIVE=ON -DLLAMA_CURL=OFF -DCMAKE_BUILD_TYPE=Release
  cmake --build build -j"$(nproc)" --target llama-cli llama-bench
  cd "$ORACLE_DIR"
fi

if [ ! -f "$MODEL" ]; then
  echo ">> downloading $(basename "$MODEL") (~645 MB)"
  curl -sSL --max-time 900 -o "$MODEL" "$MODEL_URL"
fi

echo ">> ready. try: ./ask.sh 'What should the programmer do next?'"
