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

#include "sw/gemma/gemma_model.h"

#include <math.h>
#include <string.h>

#include "sw/gemma/gemma_mmio.h"

// The layout arithmetic below must match utils/gemma_pack.py:build_layout.

static const float* wf(uint32_t off) {
  return (const float*)(GEMMA_WTCM_BASE + off);
}

// -----------------------------------------------------------------------------
// Layout
// -----------------------------------------------------------------------------
typedef struct {
  uint32_t pos;
} Alloc;

static uint32_t alloc(Alloc* a, uint32_t nbytes) {
  uint32_t off = a->pos;
  a->pos += gemma_round_up(nbytes, GEMMA_ROW_BYTES);
  return off;
}

static void alloc_matrix(Alloc* a, uint32_t rows, uint32_t cols,
                         uint32_t scale_count, uint32_t* scale_off,
                         uint32_t* data_off) {
  *scale_off = alloc(a, 4 * scale_count);
  *data_off = alloc(a, rows * gemma_row_stride_bytes(cols));
}

int gemma_init(GemmaModel* m) {
  const GemmaHeader* h = (const GemmaHeader*)GEMMA_WTCM_BASE;
  m->hdr = h;
  m->pos = 0;
  if (h->magic != GEMMA_MAGIC || h->version != 1) return 1;
  uint32_t qdim = h->heads * h->head_dim;
  uint32_t kvdim = h->kv_heads * h->head_dim;
  if (h->hidden > GEMMA_MAX_HIDDEN || qdim > GEMMA_MAX_QDIM ||
      kvdim > GEMMA_MAX_KVDIM || h->intermediate > GEMMA_MAX_INTER ||
      h->max_ctx > GEMMA_MAX_CTX || h->layers > GEMMA_MAX_LAYERS ||
      h->kv_heads != 1) {
    return 2;
  }
  Alloc a = {256};  // header
  alloc_matrix(&a, h->vocab, h->hidden, 1, &m->emb_s, &m->emb);
  m->final_norm = alloc(&a, 4 * h->hidden);
  for (uint32_t l = 0; l < h->layers; ++l) {
    GemmaLayerOffsets* lo = &m->layer[l];
    lo->ln1 = alloc(&a, 4 * h->hidden);
    alloc_matrix(&a, qdim, h->hidden, qdim, &lo->q_s, &lo->q);
    alloc_matrix(&a, kvdim, h->hidden, kvdim, &lo->k_s, &lo->k);
    alloc_matrix(&a, kvdim, h->hidden, kvdim, &lo->v_s, &lo->v);
    alloc_matrix(&a, h->hidden, qdim, h->hidden, &lo->o_s, &lo->o);
    lo->post_attn_ln = alloc(&a, 4 * h->hidden);
    lo->q_norm = alloc(&a, 4 * h->head_dim);
    lo->k_norm = alloc(&a, 4 * h->head_dim);
    lo->pre_ff_ln = alloc(&a, 4 * h->hidden);
    alloc_matrix(&a, h->intermediate, h->hidden, h->intermediate, &lo->gate_s,
                 &lo->gate);
    alloc_matrix(&a, h->intermediate, h->hidden, h->intermediate, &lo->up_s,
                 &lo->up);
    alloc_matrix(&a, h->hidden, h->intermediate, h->hidden, &lo->down_s,
                 &lo->down);
    lo->post_ff_ln = alloc(&a, 4 * h->hidden);
  }
  for (uint32_t l = 0; l < h->layers; ++l) {
    m->layer[l].kcache = alloc(&a, h->max_ctx * gemma_row_stride_bytes(kvdim));
    m->layer[l].vtcache =
        alloc(&a, kvdim * gemma_row_stride_bytes(h->max_ctx));
  }
  m->total_bytes = a.pos;
  return 0;
}

// -----------------------------------------------------------------------------
// Scalar math helpers (float32, matching the numpy reference)
//
// Decode correctness is checked token-exact against the numpy reference in
// utils/gemma_pack.py, which requires bit-identical float32 arithmetic on
// both sides. libm implementations differ between toolchains (and FMA
// contraction changes results), so the transcendental functions used on the
// decode path are implemented here with plain IEEE float32 mul/add/div and
// mirrored operation-for-operation in the reference (_gm_* functions).
// Compile this file with -ffp-contract=off.
// -----------------------------------------------------------------------------

// exp(x) = 2^n * P(r), n = floor(x*log2e + 0.5), r = x - n*ln2 (two-part).
static float gm_expf(float x) {
  if (x > 88.0f) x = 88.0f;
  if (x < -87.0f) return 0.0f;
  float t = x * 1.4426950216293335f + 0.5f;  // x*log2e + 0.5
  int32_t n = (int32_t)t;
  if ((float)n > t) n--;  // floor for negative t
  float fn = (float)n;
  float r = x - fn * 0.69314718246459961f;
  r = r - fn * -1.9046542121259336e-09f;
  float p = 1.0f + r * (1.0f + r * (0.5f + r * (0.1666666716337204f +
            r * (0.041666667908430099f + r * 0.0083333337679505348f))));
  union { float f; uint32_t u; } s;
  s.u = (uint32_t)(127 + n) << 23;
  return p * s.f;
}

static float gm_tanhf(float z) {
  float az = fabsf(z);
  float e = gm_expf(-2.0f * az);
  float t = (1.0f - e) / (1.0f + e);
  return z < 0.0f ? -t : t;
}

// sin/cos for ang >= 0 via quadrant reduction with a two-part pi/2.
static void gm_sincos(float ang, float* s, float* c) {
  int32_t k = (int32_t)(ang * 0.63661974668502808f + 0.5f);
  float fk = (float)k;
  float r = (ang - fk * 1.5707963705062866f) - fk * -4.3711388286737929e-08f;
  float r2 = r * r;
  float sr = r + r * (r2 * (-0.1666666716337204f + r2 *
             (0.0083333337679505348f + r2 * -0.00019841270113829523f)));
  float cr = 1.0f + r2 * (-0.5f + r2 * (0.041666667908430099f +
             r2 * -0.0013888889225199819f));
  switch (k & 3) {
    case 0: *s = sr;  *c = cr;  break;
    case 1: *s = cr;  *c = -sr; break;
    case 2: *s = -sr; *c = -cr; break;
    default: *s = -cr; *c = sr; break;
  }
}
static void rms_norm(float* dst, const float* src, const float* gamma,
                     uint32_t n, float eps) {
  float ms = 0.0f;
  for (uint32_t i = 0; i < n; ++i) ms += src[i] * src[i];
  float inv = 1.0f / sqrtf(ms / (float)n + eps);
  for (uint32_t i = 0; i < n; ++i) dst[i] = src[i] * inv * (1.0f + gamma[i]);
}

// Round-half-away-from-zero without libm: floor(|v|*inv + 0.5) via int
// truncation. This is bit-identical to the numpy reference (_quant_inv)
// and keeps the per-element hot path in hardware float.
static int8_t quant_one(float v, float inv_scale) {
  float t = fabsf(v) * inv_scale + 0.5f;
  if (t > 127.0f) t = 127.0f;
  int32_t q = (int32_t)t;
  return (int8_t)(v < 0.0f ? -q : q);
}

// Dynamic per-tensor int8 quantization; returns the scale.
static float dyn_quant(int8_t* dst, const float* src, uint32_t n) {
  float amax = 1e-30f;
  for (uint32_t i = 0; i < n; ++i) {
    float a = fabsf(src[i]);
    if (a > amax) amax = a;
  }
  float scale = amax / 127.0f;
  float inv = 127.0f / amax;
  for (uint32_t i = 0; i < n; ++i) dst[i] = quant_one(src[i], inv);
  return scale;
}

static void dequant_rows(float* dst, const int32_t* acc, const float* row_s,
                         float sx, uint32_t n) {
  for (uint32_t i = 0; i < n; ++i) dst[i] = (float)acc[i] * row_s[i] * sx;
}

static void rope(float* v, uint32_t d, uint32_t pos, float log_theta) {
  uint32_t half = d / 2;
  for (uint32_t i = 0; i < half; ++i) {
    float t = (float)(2 * i) / (float)d;
    float freq = gm_expf(-log_theta * t);
    float ang = (float)pos * freq;
    float c, s;
    gm_sincos(ang, &s, &c);
    float x1 = v[i], x2 = v[i + half];
    v[i] = x1 * c - x2 * s;
    v[i + half] = x2 * c + x1 * s;
  }
}

static float gelu_tanh(float x) {
  return 0.5f * x *
         (1.0f + gm_tanhf(0.7978845608028654f * (x + 0.044715f * x * x * x)));
}

// -----------------------------------------------------------------------------
// Decode step
// -----------------------------------------------------------------------------
// DTCM working buffers (16B aligned for the engine).
#define ALIGN16 __attribute__((aligned(16)))
static float g_x[GEMMA_MAX_HIDDEN];
static float g_h[GEMMA_MAX_INTER];
static float g_h2[GEMMA_MAX_INTER];
static float g_q[GEMMA_MAX_QDIM];
static float g_attn[GEMMA_MAX_QDIM];
static float g_scores[GEMMA_MAX_CTX];
static int8_t g_xq[GEMMA_MAX_INTER] ALIGN16;
static int8_t g_probs[GEMMA_MAX_CTX] ALIGN16;
static int32_t g_acc[GEMMA_MAX_INTER] ALIGN16;

static uint32_t stride_rows(uint32_t cols) {
  return gemma_row_stride_bytes(cols) / GEMMA_ROW_BYTES;
}

// Engine matvec + per-row dequantization: dst = (W @ quant(x)) scales.
static void proj(float* dst, uint32_t w_off, uint32_t s_off, uint32_t rows,
                 uint32_t cols, const int8_t* xq, float sx) {
  gemma_matvec(GEMMA_WTCM_BASE + w_off, xq, g_acc, rows, cols, 0);
  dequant_rows(dst, g_acc, wf(s_off), sx, rows);
}

uint32_t gemma_decode(GemmaModel* m, uint32_t token, float* hidden_out) {
  const GemmaHeader* h = m->hdr;
  uint32_t hidden = h->hidden;
  uint32_t qdim = h->heads * h->head_dim;
  uint32_t kvdim = h->kv_heads * h->head_dim;
  uint32_t pos = m->pos;
  uint32_t seqlen = pos + 1;

  // Embedding lookup: x = emb[token] * emb_scale * sqrt(hidden).
  {
    const int8_t* row = (const int8_t*)(GEMMA_WTCM_BASE + m->emb +
                                        token * gemma_row_stride_bytes(hidden));
    float s = h->emb_scale * sqrtf((float)hidden);
    for (uint32_t i = 0; i < hidden; ++i) g_x[i] = (float)row[i] * s;
  }

  for (uint32_t l = 0; l < h->layers; ++l) {
    const GemmaLayerOffsets* lo = &m->layer[l];
    int is_global = ((l + 1) % h->global_period) == 0;
    float log_theta =
        is_global ? h->rope_log_theta_global : h->rope_log_theta_local;

    // --- Attention block ---
    rms_norm(g_h, g_x, wf(lo->ln1), hidden, h->rms_eps);
    float sh = dyn_quant(g_xq, g_h, hidden);
    proj(g_q, lo->q, lo->q_s, qdim, hidden, g_xq, sh);
    proj(g_h2, lo->k, lo->k_s, kvdim, hidden, g_xq, sh);   // k
    proj(g_attn, lo->v, lo->v_s, kvdim, hidden, g_xq, sh); // v (temp in g_attn)

    // K: QK-norm + RoPE, then quantize into the K cache (kv_heads == 1).
    rms_norm(g_h2, g_h2, wf(lo->k_norm), h->head_dim, h->rms_eps);
    rope(g_h2, h->head_dim, pos, log_theta);
    {
      volatile int8_t* krow =
          (volatile int8_t*)(GEMMA_WTCM_BASE + lo->kcache +
                             pos * gemma_row_stride_bytes(kvdim));
      float inv = 1.0f / h->k_scale;
      for (uint32_t i = 0; i < kvdim; ++i) krow[i] = quant_one(g_h2[i], inv);
    }
    // V: quantize into the transposed V cache (column `pos`).
    {
      uint32_t vt_stride = gemma_row_stride_bytes(h->max_ctx);
      volatile int8_t* vt =
          (volatile int8_t*)(GEMMA_WTCM_BASE + lo->vtcache + pos);
      float inv = 1.0f / h->v_scale;
      for (uint32_t i = 0; i < kvdim; ++i) {
        vt[i * vt_stride] = quant_one(g_attn[i], inv);
      }
    }

    uint32_t start = 0;
    if (!is_global && seqlen > h->window) start = seqlen - h->window;

    for (uint32_t hd = 0; hd < h->heads; ++hd) {
      float* qh = &g_q[hd * h->head_dim];
      rms_norm(qh, qh, wf(lo->q_norm), h->head_dim, h->rms_eps);
      rope(qh, h->head_dim, pos, log_theta);
      for (uint32_t i = 0; i < h->head_dim; ++i) qh[i] *= h->query_scale;
      float sq = dyn_quant(g_xq, qh, h->head_dim);

      // scores[start..pos] = K[start..pos] @ q  (one K row per WTCM row).
      uint32_t rows = seqlen - start;
      gemma_matvec(GEMMA_WTCM_BASE + lo->kcache +
                       start * gemma_row_stride_bytes(kvdim),
                   g_xq, g_acc, rows, kvdim, 0);
      float smax = -1e30f;
      for (uint32_t t = 0; t < rows; ++t) {
        g_scores[t] = (float)g_acc[t] * sq * h->k_scale;
        if (g_scores[t] > smax) smax = g_scores[t];
      }
      float sum = 0.0f;
      for (uint32_t t = 0; t < rows; ++t) {
        g_scores[t] = gm_expf(g_scores[t] - smax);
        sum += g_scores[t];
      }
      float norm = 127.0f / sum;
      // probs quantized at fixed scale 1/127, zero outside the window.
      for (uint32_t t = 0; t < start; ++t) g_probs[t] = 0;
      for (uint32_t t = 0; t < rows; ++t) {
        float q = g_scores[t] * norm + 0.5f;
        if (q > 127.0f) q = 127.0f;
        g_probs[start + t] = (int8_t)q;
      }
      // attn[head] = V^T[:, 0..pos] @ probs.
      gemma_matvec(GEMMA_WTCM_BASE + lo->vtcache, g_probs, g_acc, kvdim,
                   seqlen, stride_rows(h->max_ctx));
      float vs = (1.0f / 127.0f) * h->v_scale;
      for (uint32_t i = 0; i < h->head_dim; ++i) {
        g_attn[hd * h->head_dim + i] = (float)g_acc[i] * vs;
      }
    }

    float sa = dyn_quant(g_xq, g_attn, qdim);
    proj(g_h, lo->o, lo->o_s, hidden, qdim, g_xq, sa);
    rms_norm(g_h, g_h, wf(lo->post_attn_ln), hidden, h->rms_eps);
    for (uint32_t i = 0; i < hidden; ++i) g_x[i] += g_h[i];

    // --- MLP block (GeGLU) ---
    rms_norm(g_h, g_x, wf(lo->pre_ff_ln), hidden, h->rms_eps);
    sh = dyn_quant(g_xq, g_h, hidden);
    proj(g_h, lo->gate, lo->gate_s, h->intermediate, hidden, g_xq, sh);
    proj(g_h2, lo->up, lo->up_s, h->intermediate, hidden, g_xq, sh);
    for (uint32_t i = 0; i < h->intermediate; ++i) {
      g_h[i] = gelu_tanh(g_h[i]) * g_h2[i];
    }
    float sact = dyn_quant(g_xq, g_h, h->intermediate);
    proj(g_h, lo->down, lo->down_s, hidden, h->intermediate, g_xq, sact);
    rms_norm(g_h, g_h, wf(lo->post_ff_ln), hidden, h->rms_eps);
    for (uint32_t i = 0; i < hidden; ++i) g_x[i] += g_h[i];
  }

  rms_norm(g_h, g_x, wf(m->final_norm), hidden, h->rms_eps);
  if (hidden_out != 0) {
    memcpy(hidden_out, g_h, hidden * sizeof(float));
  }
  dyn_quant(g_xq, g_h, hidden);
  // Greedy decode over the tied embedding without materializing logits.
  uint32_t next = gemma_matvec_argmax(GEMMA_WTCM_BASE + m->emb, g_xq, h->vocab,
                                      hidden, 0);
  m->pos = pos + 1;
  return next;
}
