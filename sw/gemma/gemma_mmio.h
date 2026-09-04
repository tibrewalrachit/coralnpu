/*
 * Copyright 2026 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

// Memory map and matrix-vector engine driver for the Coral NPU Gemma
// configurations (CoreMiniGemmaAxi and friends). See doc/gemma.md.

#ifndef SW_GEMMA_GEMMA_MMIO_H_
#define SW_GEMMA_GEMMA_MMIO_H_

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define GEMMA_DTCM_BASE 0x00100000u
#define GEMMA_GMV_BASE 0x00300000u
#define GEMMA_WTCM_BASE 0x40000000u

// One WTCM row: bytes fetched (int8 MACs retired) per engine cycle. Weight
// matrix rows are padded to a multiple of this.
#define GEMMA_ROW_BYTES 256u
// Maximum input-vector length of the engine.
#define GEMMA_MAX_COLS 2048u

// Matrix-vector engine CSRs (word offsets from GEMMA_GMV_BASE).
typedef struct {
  volatile uint32_t ctrl;        // bit0: start
  volatile uint32_t status;      // bit0: busy, bit1: done
  volatile uint32_t w_base;      // weight base byte address (256B aligned)
  volatile uint32_t in_base;     // input vector address in DTCM (16B aligned)
  volatile uint32_t out_base;    // int32 output address in DTCM (16B aligned)
  volatile uint32_t rows;        // number of output rows
  volatile uint32_t cols;        // input elements (<= GEMMA_MAX_COLS)
  volatile uint32_t row_stride;  // row pitch in WTCM rows (0 = packed)
  volatile uint32_t mode;        // bit0: argmax only
  volatile uint32_t argmax_idx;  // RO
  volatile uint32_t argmax_val;  // RO (int32)
  volatile uint32_t cycles;      // RO: busy cycles of last operation
} GemmaMatVecCsr;

#define GEMMA_GMV ((GemmaMatVecCsr*)GEMMA_GMV_BASE)

#define GEMMA_GMV_MODE_OUTPUT 0u
#define GEMMA_GMV_MODE_ARGMAX 1u

static inline uint32_t gemma_round_up(uint32_t v, uint32_t align) {
  return (v + align - 1) & ~(align - 1);
}

// Bytes occupied by one padded row of a matrix with `cols` int8 columns.
static inline uint32_t gemma_row_stride_bytes(uint32_t cols) {
  return gemma_round_up(cols, GEMMA_ROW_BYTES);
}

// Runs rows x cols int8 matvec: out_int32[r] = sum_c W[r][c] * x[c].
// `w_addr` is a byte address inside the WTCM (256B aligned); `x` and `out`
// must lie in the DTCM and be 16B aligned. Blocks until done.
static inline void gemma_matvec(uint32_t w_addr, const int8_t* x, int32_t* out,
                                uint32_t rows, uint32_t cols,
                                uint32_t row_stride_rows) {
  GemmaMatVecCsr* gmv = GEMMA_GMV;
  gmv->w_base = w_addr;
  gmv->in_base = (uint32_t)x;
  gmv->out_base = (uint32_t)out;
  gmv->rows = rows;
  gmv->cols = cols;
  gmv->row_stride = row_stride_rows;
  gmv->mode = GEMMA_GMV_MODE_OUTPUT;
  gmv->ctrl = 1;
  while (!(gmv->status & 2)) {
  }
}

// Argmax-mode matvec used for greedy decoding over the vocabulary: returns
// the row index with the maximum accumulator, without materializing outputs.
static inline uint32_t gemma_matvec_argmax(uint32_t w_addr, const int8_t* x,
                                           uint32_t rows, uint32_t cols,
                                           uint32_t row_stride_rows) {
  GemmaMatVecCsr* gmv = GEMMA_GMV;
  gmv->w_base = w_addr;
  gmv->in_base = (uint32_t)x;
  gmv->out_base = 0;
  gmv->rows = rows;
  gmv->cols = cols;
  gmv->row_stride = row_stride_rows;
  gmv->mode = GEMMA_GMV_MODE_ARGMAX;
  gmv->ctrl = 1;
  while (!(gmv->status & 2)) {
  }
  return gmv->argmax_idx;
}

#ifdef __cplusplus
}  // extern "C"
#endif

#endif  // SW_GEMMA_GEMMA_MMIO_H_
