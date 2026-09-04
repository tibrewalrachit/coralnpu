# Gemma on Coral NPU: all-SRAM LLM decoding

This document describes the **Gemma configuration** of Coral NPU: a variant
of the core that stores an entire quantized LLM —
[google/gemma-3-270m](https://huggingface.co/google/gemma-3-270m) — in
on-chip SRAM and decodes at hundreds of tokens per second.

Token generation on small LLMs is memory-bandwidth bound: every generated
token reads every weight once. The Gemma configuration attacks exactly that
bottleneck with two additions to the base core:

1. **WTCM (weight TCM)** — a large, banked on-chip SRAM (320 MiB for
   Gemma-3-270M at int8) holding weights, per-channel scales and the KV
   cache, mapped into the core's data address space.
2. **A streaming int8 matrix-vector engine** — reads WTCM rows 2048 bits at
   a time and retires **256 int8 MACs per cycle**, with a fused argmax mode
   that greedy-decodes over the 262K-entry vocabulary without ever
   materializing logits.

The scalar core (with FPU) orchestrates: RMSNorm, RoPE, softmax, GeGLU and
quantization run on the CPU in float32; every matrix product runs on the
engine.

```
                 +-----------------------------------------------+
                 |              CoreMiniGemmaAxi                 |
   AXI slave --->|  fabric mux                                   |
                 |   |-- ITCM (1 MiB)   <---- ibus               |
                 |   |-- DTCM (1 MiB)   <---- dbus --+           |
                 |   |-- CSRs           |            |           |
                 |   |-- MatVec CSRs  <-+   +--------+--------+  |
                 |   |-- WTCM 128b port <---| scalar core+FPU |  |
                 |        |                 +-----------------+  |
                 |  +-----+------+   2048b   +--------------+    |
                 |  | WTCM       |==========>| MatVec engine|    |
                 |  | (<=512MiB) |           | 256 MAC/cyc  |    |
                 |  +------------+           +--(DTCM port)-+    |
                 +-----------------------------------------------+
```

## Memory map

`MemoryRegions.gemma` extends the highmem map (so highmem linker scripts
and hosts keep working) with two regions:

| Region       | Base         | Size          | Type |
|--------------|--------------|---------------|------|
| ITCM         | `0x0000_0000`| 1 MiB         | IMEM |
| DTCM         | `0x0010_0000`| 1 MiB         | DMEM |
| Core CSRs    | `0x0020_0000`| 4 KiB         | Peripheral |
| MatVec CSRs  | `0x0030_0000`| 4 KiB         | DMEM (engine registers) |
| WTCM         | `0x4000_0000`| configurable  | DMEM |

The WTCM and the engine CSRs are ordinary DMEM regions: the LSU reaches
them over the dbus with single-cycle loads/stores, and the AXI slave
reaches them through the fabric (that is how a host loads the model image).
The engine itself has a private 2048-bit read port into the WTCM and a
fourth arbiter port into the DTCM for input vectors and results.

Emit the configuration with:

```
--enableGemma=True --wtcmSizeKBytes=<size> --itcmSizeKBytes=1024 --dtcmSizeKBytes=1024
```

The checked-in `core_mini_gemma_axi_cc_library` target uses an 8 MiB WTCM
to keep Verilator builds fast; a full Gemma-3-270M build uses
`--wtcmSizeKBytes=327680` (320 MiB).

## Does 320 MiB of SRAM fit on a die?

Yes — this is the design point of SRAM-resident inference accelerators. In
a 5 nm-class process, high-density 6T SRAM is ≈0.021 µm²/bit, so 320 MiB
≈ 2.7 Gbit ≈ 56 mm² of bit cells — order 100 mm² with periphery and
banking, before the (small) core and engine. For precedent: Groq's LPU
carries 230 MB of on-die SRAM, IBM NorthPole 224 MB. An int4 variant of
the engine (future work, `MODE` bit reserved) halves the requirement to
≈165 MiB.

In this repository the WTCM is modeled behaviourally (`WeightMem`, one
`SyncReadMem` of 2048-bit rows) — the same abstraction level the TCMs use
before macro replacement. A silicon implementation replaces it with an
array of the existing 2048x128 macros: one 2048-bit row read = a same-index
read across 16 banked macros; the 128-bit fabric port reads one bank.

## The matrix-vector engine

`MatVecUnit` (hdl/chisel/src/coralnpu/Gemma.scala) computes
`out[r] = Σc W[r][c] · x[c]` with int8 weights and activations and int32
accumulators:

* Weight rows are padded to 256 B (one WTCM row). The engine streams one
  row-chunk per cycle in steady state — the 16-lane × 16-element product
  tree is pipelined over two stages, so 256 MACs/cycle sustained.
* `COLS ≤ 2048` (`x` is buffered locally; loaded from DTCM at 16 B/cycle).
* `ROW_STRIDE` decouples row pitch from row length, which lets the
  transposed V cache use a fixed 2048-token pitch.
* Mode 0 writes int32 results to DTCM (four rows per 128-bit write);
  mode 1 (`ARGMAX`) keeps only the running maximum and its row index —
  greedy decoding over the tied embedding matrix costs no output
  bandwidth and no logit storage.
* `CYCLES` counts busy cycles for performance measurements.

Registers (word offsets from `0x0030_0000`): `CTRL`, `STATUS`, `W_BASE`,
`IN_BASE`, `OUT_BASE`, `ROWS`, `COLS`, `ROW_STRIDE`, `MODE`,
`ARGMAX_IDX`, `ARGMAX_VAL`, `CYCLES`. See `sw/gemma/gemma_mmio.h`.

Dequantization (per-output-channel float scale × dynamic per-tensor
activation scale) runs on the CPU between engine calls.

## Model image

`utils/gemma_pack.py` converts a HuggingFace safetensors snapshot into the
WTCM image: a 256-byte header (dims, RoPE thetas, quantization scales),
then per-tensor blocks of float32 per-row scales + row-padded int8 data,
then the KV-cache arena. Quantization is symmetric int8: per-row scales
for projections, one per-tensor scale for the tied embedding (argmax over
logits is invariant to a positive per-tensor scale, which is what makes
the fused-argmax logit path exact). The K cache stores per-token rows
(one 256 B row per token); the V cache is stored transposed with a fixed
row pitch so attention·V is a strided matvec.

For Gemma-3-270M at int8:

| Block                | Size |
|----------------------|-----------|
| Embedding (262144×640, tied with logits) | 192.0 MiB |
| 18 transformer layers | 108.7 MiB |
| KV cache (2048 ctx)  | 18.0 MiB |
| **Total**            | **318.7 MiB** |

## Performance

Every decode step streams each weight byte through the engine exactly once
(the embedding matrix once for logits, plus an embedding-row read for the
input token), so engine cycles per token are close to
`padded weight bytes / 256`:

| Component | engine cycles/token |
|-----------|--------------------|
| 18 layers of projections + MLP | 442K |
| Logits over 262K vocab (argmax mode) | 786K |
| Attention at 2048-token context | ≤ 203K |
| **Total** | **≈ 1.43M** |

That is **≈350 tokens/s at 500 MHz** and **≈700 tokens/s at 1 GHz**,
engine-bound, at full 2048-token context (short contexts are faster). The
baseline scalar core reading the same weights over a 128-bit bus tops out
16× lower on bandwidth alone, before instruction overhead — and a
DRAM-backed design at, say, 8 GB/s LPDDR sustains ≈25 tokens/s.

The scalar-float glue between engine calls (norms, RoPE, softmax, GeGLU,
requantization) is currently plain C on the scalar core. Measured on the
simulated core with the tiny test model, a decode step costs ≈139K cycles
(engine share ≈2K), i.e. roughly 50–70 cycles per glue element. Scaled to
the real model's ≈270K glue elements per token, the scalar core would add
≈13M cycles/token and dominate the 1.43M-cycle engine time. Closing that
gap is software work on the same hardware: the `RvvCoreMiniGemmaAxi`
variant runs the same engine next to the RVV unit, and vectorizing the
glue loops (int8 quant/dequant, polynomial exp/GeLU) at 4–16 lanes plus
double-buffering engine calls against CPU post-processing brings the glue
under the engine time, i.e. to the engine-bound numbers above.

## Software

* `sw/gemma/gemma_mmio.h` — memory map + engine driver.
* `sw/gemma/gemma_model.{h,c}` — full Gemma-3 decode runtime: embedding,
  sandwich RMSNorms, GQA attention with QK-norm, RoPE (local/global
  thetas), sliding-window + full-attention layer interleave, GeGLU MLP,
  KV-cache management, greedy decoding via fused argmax. The runtime reads
  all dimensions from the image header, so the same binary runs the tiny
  test model and the real 270M model.
* `utils/gemma_pack.py` — image packer + bit-faithful numpy reference
  (mirrors the C runtime's quantization arithmetic), HF safetensors import
  (no torch needed), and a tiny-model generator for RTL tests.

## Verification

`tests/cocotb/gemma/` (suite `gemma_tests`, model `CoreMiniGemmaAxi`):

* `gemma_engine_sim.py` — host-driven (AXI slave) tests: WTCM
  write/readback; engine matvec vs numpy **bit-exact** across shapes
  (1×1 … 3×2048, partial chunks), argmax mode, strided (V^T) mode,
  back-to-back reuse.
* `gemma_forward_sim.py` + `gemma_forward_test.c` — end-to-end: loads a
  tiny random Gemma-3-style model (2 layers, both attention types,
  generated with expected outputs by `gemma_pack.py tiny`) into the WTCM,
  runs the real runtime on the simulated core for several decode steps,
  and checks generated tokens exactly and the final hidden state to 2%.
  Token-exactness holds across toolchains because the runtime's
  transcendental kernels (`gm_expf`/`gm_tanhf`/`gm_sincos`) are plain
  IEEE float32 and mirrored operation-for-operation in the reference,
  and the runtime is compiled with `-ffp-contract=off`.

## Limitations / future work

* `kv_heads == 1` only (Gemma-3-270M's configuration); larger models need
  per-head K-row slicing in the runtime.
* K/V cache uses fixed quantization scales (`k_scale`/`v_scale` header
  fields); calibration for the real checkpoint is untested — quality
  work, not correctness work.
* int4 weight mode (halves SRAM) is reserved in the register map but not
  implemented.
* Prefill is sequential decode; a batched prefill mode on the engine
  (matrix-matrix) is straightforward but unimplemented.
* No tokenizer on-core: the host feeds token ids over AXI.
