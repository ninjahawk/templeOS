#!/bin/bash
# Shared config for the local-model scripts.
export ORACLE_DIR="${ORACLE_DIR:-$HOME/oracle}"
export LLAMA_BIN="$ORACLE_DIR/llama.cpp/build/bin"
export MODEL_FILE="${MODEL_FILE:-qwen2.5-0.5b-instruct-q8_0.gguf}"
export MODEL="$ORACLE_DIR/$MODEL_FILE"
export MODEL_URL="https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/$MODEL_FILE"
export LD_LIBRARY_PATH="$LLAMA_BIN${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
