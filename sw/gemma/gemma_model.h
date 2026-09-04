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

// Gemma-3 decode runtime for the Coral NPU Gemma configurations.
//
// The model image (weights, per-channel scales and KV cache) lives in the
// weight TCM at GEMMA_WTCM_BASE, in the format produced by
// utils/gemma_pack.py. All matrix-vector products run on the streaming
// int8 engine (see gemma_mmio.h); norms, RoPE, softmax and activation
// functions run on the scalar core in float32.

#ifndef SW_GEMMA_GEMMA_MODEL_H_
#define SW_GEMMA_GEMMA_MODEL_H_

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define GEMMA_MAGIC 0x33414D47u  // "GMA3"

// Compile-time maxima (bounds DTCM buffer sizes). Gemma-3-270M needs
// hidden=640, qdim=1024, intermediate=2048, ctx<=2048, layers=18.
#define GEMMA_MAX_HIDDEN 640
#define GEMMA_MAX_QDIM 1024
#define GEMMA_MAX_KVDIM 256
#define GEMMA_MAX_INTER 2048
#define GEMMA_MAX_CTX 2048
#define GEMMA_MAX_LAYERS 32

// WTCM image header (256 bytes at GEMMA_WTCM_BASE); packed by
// utils/gemma_pack.py:pack_header.
typedef struct {
  uint32_t magic;
  uint32_t version;
  uint32_t hidden;
  uint32_t layers;
  uint32_t heads;
  uint32_t kv_heads;
  uint32_t head_dim;
  uint32_t intermediate;
  uint32_t vocab;
  uint32_t max_ctx;
  uint32_t window;
  uint32_t global_period;
  float rope_theta_global;
  float rope_theta_local;
  float emb_scale;
  float k_scale;
  float v_scale;
  float rms_eps;
  float query_scale;
} GemmaHeader;

// Byte offsets (from GEMMA_WTCM_BASE) of one layer's tensors. For matrices,
// `x` is the int8 data and `x_s` the float32 per-row scale array.
typedef struct {
  uint32_t ln1;
  uint32_t q_s, q;
  uint32_t k_s, k;
  uint32_t v_s, v;
  uint32_t o_s, o;
  uint32_t post_attn_ln;
  uint32_t q_norm, k_norm;
  uint32_t pre_ff_ln;
  uint32_t gate_s, gate;
  uint32_t up_s, up;
  uint32_t down_s, down;
  uint32_t post_ff_ln;
  uint32_t kcache;
  uint32_t vtcache;
} GemmaLayerOffsets;

typedef struct {
  const GemmaHeader* hdr;
  uint32_t emb_s, emb;
  uint32_t final_norm;
  GemmaLayerOffsets layer[GEMMA_MAX_LAYERS];
  uint32_t total_bytes;
  uint32_t pos;  // next decode position
} GemmaModel;

// Parses the WTCM header and computes tensor offsets. Returns 0 on success,
// nonzero on a bad image (wrong magic/version or over-limit dimensions).
int gemma_init(GemmaModel* m);

// Runs one decode step for `token` at the current position and returns the
// greedy (argmax) next token. If `hidden_out` is non-NULL, the final
// pre-logits hidden state (hdr->hidden floats) is copied there.
uint32_t gemma_decode(GemmaModel* m, uint32_t token, float* hidden_out);

#ifdef __cplusplus
}  // extern "C"
#endif

#endif  // SW_GEMMA_GEMMA_MODEL_H_
