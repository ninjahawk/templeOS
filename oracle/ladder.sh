#!/bin/bash
# Download -> benchmark -> delete, up a ladder of model sizes.
export LD_LIBRARY_PATH=/home/user/oracle/llama.cpp/build/bin
BIN=/home/user/oracle/llama.cpp/build/bin/llama-bench
cd /home/user/oracle
RES=/home/user/oracle/ladder.results
BASE=https://huggingface.co/Qwen

run() {  # name repo shard_count filepattern
  local name=$1 repo=$2 n=$3 pat=$4
  echo "### $name : downloading" >> $RES
  local first=""
  if [ "$n" = "1" ]; then
    f="$pat"
    curl -sSL --max-time 1800 -o "$f" "$BASE/$repo/resolve/main/$f" || { echo "$name DOWNLOAD_FAIL" >>$RES; return; }
    first="$f"
  else
    for i in $(seq -f "%05g" 1 $n); do
      f="${pat}-${i}-of-$(printf '%05d' $n).gguf"
      curl -sSL --max-time 1800 -o "$f" "$BASE/$repo/resolve/main/$f" || { echo "$name DOWNLOAD_FAIL" >>$RES; return; }
      [ "$i" = "00001" ] && first="$f"
    done
  fi
  local sz=$(du -cm ${pat}*.gguf 2>/dev/null | tail -1 | cut -f1)
  echo "### $name : size ${sz}MB : benchmarking" >> $RES
  $BIN -m "$first" -t 4 -p 128 -n 64 -r 2 2>/dev/null | grep -E "pp128|tg64" | sed "s/^/$name |/" >> $RES
  echo "### $name : done" >> $RES
  rm -f ${pat}*.gguf
  df -h / | tail -1 >> $RES
}

run "1.5B-Q4KM" Qwen2.5-1.5B-Instruct-GGUF 1 qwen2.5-1.5b-instruct-q4_k_m.gguf
run "3B-Q4KM"   Qwen2.5-3B-Instruct-GGUF   1 qwen2.5-3b-instruct-q4_k_m.gguf
run "7B-Q4KM"   Qwen2.5-7B-Instruct-GGUF   2 qwen2.5-7b-instruct-q4_k_m
run "14B-Q4KM"  Qwen2.5-14B-Instruct-GGUF  3 qwen2.5-14b-instruct-q4_k_m
echo "LADDER_COMPLETE" >> $RES
