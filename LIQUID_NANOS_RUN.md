# Liquid Nanos on CPU (llama.cpp) — run log

Request: run the models from
https://www.liquid.ai/blog/introducing-liquid-nanos-frontier-grade-performance-on-everyday-devices

Where: this 4-vCPU / 15 GB x86_64 sandbox, CPU only. Not the Coral NPU (its
8 KB ITCM / 32 KB DTCM cannot hold a 350M-parameter model) and not the
CVA6/FireSim Linux (not booted yet). Script + prompts: `tools/liquid-nanos/`.

## Setup (all state-mutating commands)

| Command | Outcome |
|---|---|
| `git clone --depth 1 https://github.com/ggml-org/llama.cpp` @ `4d91760`; `cmake -DGGML_NATIVE=ON -DLLAMA_CURL=OFF`; build `llama-completion llama-bench` | OK (~8 min) |
| Download official GGUFs from `huggingface.co/LiquidAI/<model>-GGUF`: 350M models as Q8_0 (379 MB each), 1.2B models as Q4_K_M (575–731 MB) | OK, 6 files |
| Prompt formats taken from each model card (system prompts, special tokens, sampling) | recorded in `tools/liquid-nanos/*.sys|*.user` |

## Throughput (`llama-bench`, 4 threads, pp128 / tg64)

| Model | Prompt tok/s | Generate tok/s |
|---|---|---|
| LFM2-350M Q8_0 | 428 ± 22 | 53.6 ± 1.0 |
| LFM2-1.2B Q4_K_M | 167 ± 4 | 28.9 ± 2.5 |

## Results (greedy unless noted; full outputs reproduced verbatim)

### LFM2-350M-Extract (Q8_0) — invoice e-mail → JSON with a given schema
Correct: all fields right, 134 tokens at 52 tok/s.
```json
{"invoice_number": "AF-2026-0917", "vendor": "Acme Fabrication GmbH", "date": "2026-09-03",
 "total_amount": 366.0, "currency": "EUR",
 "line_items": [{"description": "4 aluminium enclosures", "quantity": 4, "unit_price": 85.5},
                {"description": "2 mounting kits", "quantity": 2, "unit_price": 12.0}]}
```

### LFM2-1.2B-Extract (Q4_K_M) — same input
Correct, and cleaner item descriptions ("Aluminium enclosure", "Mounting kit"). 134 tokens at 28 tok/s.

### LFM2-350M-ENJP-MT (Q8_0) — EN→JA, system prompt "Translate to Japanese.", temp 0.5
Input: *The FPGA build finished overnight, and the Linux kernel booted on the first try.*
Output: **FPGAの構築作業は一晩で完了し、Linuxカーネルは最初の試みで起動しました。** — faithful. 30 tokens at 58 tok/s.

### LFM2-1.2B-RAG (Q4_K_M) — question over a Coral NPU paragraph
Question: total tightly coupled memory, and which interface lets an external CPU configure it.
Output: *"Coral NPU has a total of 16 KB of tightly coupled memory (TCM) consisting of an 8 KB ITCM for instructions and a 8 KB DTCM for data. The AXI4 interfaces functioning as both manager and subordinate allow an external CPU to configure it."*
**Partly wrong:** the context says 32 KB DTCM (total 40 KB); the model wrote 8 KB / 16 KB. The AXI4 part is right. 61 tokens at 29 tok/s.

### LFM2-1.2B-Tool (Q4_K_M) — two tools in the system prompt, user asks about a build
Output (special tokens shown): `<|tool_call_start|>[get_fpga_build_status(build_name="firesim_cva6_singlecore_no_nic_coralnpu")]<|tool_call_end|>`
Correct tool, correct argument, no extra text. 31 tokens at 28 tok/s.

### LFM2-350M-Math (Q8_0) — temp 0.6 / top-p 0.95 / min-p 0.1 / rep 1.05
Attempt 1 (word problem with "two builds run in parallel"): 1500-token chain of thought, never reached an answer, kept re-parsing the wording. Hit the token limit.
Attempt 2 (`tools/liquid-nanos/math2.user`: "Two build instances each run for 4 hours at $0.74/h. One FPGA instance runs for 2 hours at $1.98/h. Total?"): finished in 655 tokens with `\boxed{9.40}`. **Wrong** — it swapped the hours (computed 2×0.74 and 4×1.98); correct answer is 2×4×0.74 + 2×1.98 = **9.88**.

## Take-aways
- All six run comfortably on a 4-core CPU: ~50 tok/s for 350M-Q8, ~28 tok/s for 1.2B-Q4.
- Extraction, translation, and tool-calling Nanos did their job on first try.
- The RAG and Math Nanos both made numeric mistakes on small, clean inputs; treat their outputs as needing verification.
- None of this touches the Coral NPU; running a Nano on the FireSim CVA6 Linux would need llama.cpp cross-built for rv64 (no vector extension on CVA6) and would be very slow — possible as a demo, not useful as a benchmark.
