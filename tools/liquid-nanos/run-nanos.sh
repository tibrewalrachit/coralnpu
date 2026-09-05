#!/usr/bin/env bash
# Run the six Liquid Nanos (LFM2 task models) on CPU with llama.cpp.
# Usage: ./run-nanos.sh [model dir] [llama.cpp bin dir]
# Downloads the official LiquidAI GGUFs if missing. Prompts live next to this script.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
M="${1:-$HOME/nanos}"; B="${2:-$HOME/llama.cpp/build/bin}"
mkdir -p "$M"
get() { [ -s "$M/$2" ] || curl -sSL -o "$M/$2" "https://huggingface.co/LiquidAI/$1-GGUF/resolve/main/$2"; }
get LFM2-350M-Extract LFM2-350M-Extract-Q8_0.gguf
get LFM2-1.2B-Extract LFM2-1.2B-Extract-Q4_K_M.gguf
get LFM2-350M-ENJP-MT LFM2-350M-ENJP-MT-Q8_0.gguf
get LFM2-1.2B-RAG     LFM2-1.2B-RAG-Q4_K_M.gguf
get LFM2-1.2B-Tool    LFM2-1.2B-Tool-Q4_K_M.gguf
get LFM2-350M-Math    LFM2-350M-Math-Q8_0.gguf
run() { name=$1; model=$2; shift 2; sysarg=(); [ -f "$HERE/$name.sys" ] && sysarg=(-sys "$(cat "$HERE/$name.sys")")
  echo "================ $name ($model)"
  "$B/llama-completion" -m "$M/$model" -t "$(nproc)" -c 4096 -cnv -st --no-display-prompt "${sysarg[@]}" \
    -p "$(cat "$HERE/$name.user")" "$@" 2> "$M/$name-${model%%.gguf}.stderr" < /dev/null; echo; }
# Sampling per the model cards: greedy for Extract/RAG/Tool; MT 0.5/min-p 0.1/rep 1.05; Math 0.6/top-p 0.95/min-p 0.1/rep 1.05
run extract LFM2-350M-Extract-Q8_0.gguf   --temp 0 -n 400
run extract LFM2-1.2B-Extract-Q4_K_M.gguf --temp 0 -n 400
run enjp    LFM2-350M-ENJP-MT-Q8_0.gguf   --temp 0.5 --top-p 1.0 --min-p 0.1 --repeat-penalty 1.05 -n 200
run rag     LFM2-1.2B-RAG-Q4_K_M.gguf     --temp 0 -n 300
run tool    LFM2-1.2B-Tool-Q4_K_M.gguf    --temp 0 -n 200 -sp
run math2   LFM2-350M-Math-Q8_0.gguf      --temp 0.6 --top-p 0.95 --min-p 0.1 --repeat-penalty 1.05 -n 2500 -sp
