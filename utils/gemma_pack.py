# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Packs Gemma-3 weights into the Coral NPU Gemma WTCM image format.

The image layout here is the contract shared with the C runtime in
sw/gemma/ (gemma_layout.c computes the same offsets from the same header).
See doc/gemma.md for the format description.

Usage:
  # Pack a HuggingFace google/gemma-3-270m snapshot (safetensors):
  python3 utils/gemma_pack.py hf --snapshot /path/to/gemma-3-270m \
      --out gemma3_270m_wtcm.bin

  # Generate a tiny random model + expected outputs for RTL tests:
  python3 utils/gemma_pack.py tiny --out-dir /tmp/gemma_tiny --seed 7
"""

import argparse
import dataclasses
import json
import struct
import sys

import numpy as np

ROW_BYTES = 256
GEMMA_MAGIC = 0x33414D47  # "GMA3"
HEADER_BYTES = 256


@dataclasses.dataclass
class GemmaConfig:
  hidden: int
  layers: int
  heads: int
  kv_heads: int
  head_dim: int
  intermediate: int
  vocab: int
  max_ctx: int
  window: int
  global_period: int  # every Nth layer (1-based) uses global attention
  rope_theta_global: float = 1e6
  rope_theta_local: float = 1e4
  k_scale: float = 8.0 / 127  # fixed KV-cache quantization scales
  v_scale: float = 8.0 / 127
  rms_eps: float = 1e-6
  query_scale: float = 1.0 / 16  # 1/sqrt(query_pre_attn_scalar)

  @property
  def qdim(self):
    return self.heads * self.head_dim

  @property
  def kvdim(self):
    return self.kv_heads * self.head_dim

  def is_global(self, layer):
    return (layer + 1) % self.global_period == 0


GEMMA3_270M = GemmaConfig(
    hidden=640, layers=18, heads=4, kv_heads=1, head_dim=256,
    intermediate=2048, vocab=262144, max_ctx=2048, window=512,
    global_period=6, query_scale=1.0 / np.sqrt(256.0))


def align(n, a=ROW_BYTES):
  return (n + a - 1) // a * a


def row_stride(cols):
  return align(cols)


def rquant(x, scale):
  """round-half-away-from-zero int8 quantization, matching C roundf."""
  q = np.sign(x) * np.floor(np.abs(x) / scale + 0.5)
  return np.clip(q, -127, 127).astype(np.int8)


# =============================================================================
# Layout: must match sw/gemma/gemma_layout.c exactly.
# =============================================================================
def build_layout(c: GemmaConfig):
  """Returns ({name: offset}, total_bytes). All offsets 256B aligned."""
  off = {}
  pos = HEADER_BYTES

  def alloc(name, nbytes):
    nonlocal pos
    off[name] = pos
    pos += align(nbytes)

  def alloc_matrix(name, rows, cols, per_tensor_scale=False):
    scales = 1 if per_tensor_scale else rows
    alloc(f"{name}.scale", 4 * scales)
    alloc(f"{name}.data", rows * row_stride(cols))

  alloc_matrix("embedding", c.vocab, c.hidden, per_tensor_scale=True)
  alloc("final_norm", 4 * c.hidden)
  for l in range(c.layers):
    alloc(f"l{l}.ln1", 4 * c.hidden)
    alloc_matrix(f"l{l}.q", c.qdim, c.hidden)
    alloc_matrix(f"l{l}.k", c.kvdim, c.hidden)
    alloc_matrix(f"l{l}.v", c.kvdim, c.hidden)
    alloc_matrix(f"l{l}.o", c.hidden, c.qdim)
    alloc(f"l{l}.post_attn_ln", 4 * c.hidden)
    alloc(f"l{l}.q_norm", 4 * c.head_dim)
    alloc(f"l{l}.k_norm", 4 * c.head_dim)
    alloc(f"l{l}.pre_ff_ln", 4 * c.hidden)
    alloc_matrix(f"l{l}.gate", c.intermediate, c.hidden)
    alloc_matrix(f"l{l}.up", c.intermediate, c.hidden)
    alloc_matrix(f"l{l}.down", c.hidden, c.intermediate)
    alloc(f"l{l}.post_ff_ln", 4 * c.hidden)
  for l in range(c.layers):
    alloc(f"l{l}.kcache", c.max_ctx * row_stride(c.kvdim))
    alloc(f"l{l}.vtcache", c.kvdim * row_stride(c.max_ctx))
  return off, pos


def log_theta32(theta):
  """float32 log(theta): the value stored in the header and used by both
  the C runtime and the reference for RoPE frequencies."""
  return np.float32(np.log(np.float64(theta)))


def pack_header(c: GemmaConfig):
  h = struct.pack(
      "<12I9f",
      GEMMA_MAGIC, 1, c.hidden, c.layers, c.heads, c.kv_heads, c.head_dim,
      c.intermediate, c.vocab, c.max_ctx, c.window, c.global_period,
      c.rope_theta_global, c.rope_theta_local, 0.0,  # emb scale patched below
      c.k_scale, c.v_scale, c.rms_eps, c.query_scale,
      float(log_theta32(c.rope_theta_global)),
      float(log_theta32(c.rope_theta_local)))
  return h + b"\x00" * (HEADER_BYTES - len(h))


def pack_matrix(image, off, name, w, per_tensor_scale=False):
  """Quantizes float32 [rows, cols] to int8 with per-row (or per-tensor)
  scales and writes scales+data into the image."""
  rows, cols = w.shape
  if per_tensor_scale:
    s = np.full(1, max(np.abs(w).max(), 1e-30) / 127, np.float32)
    q = rquant(w, s[0])
  else:
    s = (np.maximum(np.abs(w).max(axis=1), 1e-30) / 127).astype(np.float32)
    q = rquant(w, s[:, None])
  sb = s.tobytes()
  image[off[f"{name}.scale"]:off[f"{name}.scale"] + len(sb)] = \
      np.frombuffer(sb, np.uint8)
  stride = row_stride(cols)
  data = np.zeros([rows, stride], np.int8)
  data[:, :cols] = q
  db = data.tobytes()
  image[off[f"{name}.data"]:off[f"{name}.data"] + len(db)] = \
      np.frombuffer(db, np.uint8)
  return q, s


def pack_vector(image, off, name, v):
  b = v.astype(np.float32).tobytes()
  image[off[name]:off[name] + len(b)] = np.frombuffer(b, np.uint8)


def pack_model(c: GemmaConfig, tensors):
  """tensors: dict of float32 arrays keyed by canonical names:
  embedding [vocab, hidden]; final_norm [hidden]; per layer l:
  l{l}.{ln1,post_attn_ln,pre_ff_ln,post_ff_ln} [hidden];
  l{l}.{q_norm,k_norm} [head_dim];
  l{l}.q [qdim, hidden]; l{l}.k/v [kvdim, hidden]; l{l}.o [hidden, qdim];
  l{l}.gate/up [inter, hidden]; l{l}.down [hidden, inter].
  Returns (image bytes, quantized dict for the reference model)."""
  off, total = build_layout(c)
  image = np.zeros(total, np.uint8)
  image[:HEADER_BYTES] = np.frombuffer(pack_header(c), np.uint8)
  quant = {}

  q, s = pack_matrix(image, off, "embedding", tensors["embedding"],
                     per_tensor_scale=True)
  quant["embedding"] = (q, s)
  # Patch the embedding per-tensor scale into the header (word 14).
  image[56:60] = np.frombuffer(np.float32(s[0]).tobytes(), np.uint8)
  pack_vector(image, off, "final_norm", tensors["final_norm"])
  for l in range(c.layers):
    for name in ["ln1", "post_attn_ln", "q_norm", "k_norm", "pre_ff_ln",
                 "post_ff_ln"]:
      pack_vector(image, off, f"l{l}.{name}", tensors[f"l{l}.{name}"])
    for name in ["q", "k", "v", "o", "gate", "up", "down"]:
      quant[f"l{l}.{name}"] = pack_matrix(image, off, f"l{l}.{name}",
                                          tensors[f"l{l}.{name}"])
  return image, quant, off


# =============================================================================
# Reference model: mirrors the C runtime (sw/gemma/gemma_model.c) step by
# step, including engine-exact int32 matvecs and quantization points.
#
# Token-exact agreement with the on-core runtime requires bit-identical
# float32 arithmetic, so the transcendental functions below (_gm_*) are
# element-wise float32 mirrors of the gm_* implementations in
# sw/gemma/gemma_model.c — same constants, same operation order, no FMA.
# =============================================================================
_F = np.float32


def _gm_expf(x):
  x = np.minimum(np.asarray(x, _F), _F(88.0))
  lo = x < _F(-87.0)
  t = x * _F(1.4426950216293335) + _F(0.5)
  n = np.floor(t).astype(np.int32)
  fn = n.astype(_F)
  r = x - fn * _F(0.69314718246459961)
  r = r - fn * _F(-1.9046542121259336e-09)
  p = _F(1.0) + r * (_F(1.0) + r * (_F(0.5) + r * (_F(0.1666666716337204) +
      r * (_F(0.041666667908430099) + r * _F(0.0083333337679505348)))))
  scale = np.ldexp(_F(1.0), n)
  return np.where(lo, _F(0.0), (p * scale).astype(_F)).astype(_F)


def _gm_tanhf(z):
  z = np.asarray(z, _F)
  az = np.abs(z)
  e = _gm_expf(_F(-2.0) * az)
  t = (_F(1.0) - e) / (_F(1.0) + e)
  return np.where(z < _F(0.0), -t, t).astype(_F)


def _gm_sincos(ang):
  """ang >= 0, element-wise; returns (sin, cos)."""
  ang = np.asarray(ang, _F)
  k = np.floor(ang * _F(0.63661974668502808) + _F(0.5)).astype(np.int32)
  fk = k.astype(_F)
  r = (ang - fk * _F(1.5707963705062866)) - fk * _F(-4.3711388286737929e-08)
  r2 = r * r
  sr = r + r * (r2 * (_F(-0.1666666716337204) + r2 *
       (_F(0.0083333337679505348) + r2 * _F(-0.00019841270113829523))))
  cr = _F(1.0) + r2 * (_F(-0.5) + r2 * (_F(0.041666667908430099) +
       r2 * _F(-0.0013888889225199819)))
  q = k & 3
  sin = np.select([q == 0, q == 1, q == 2], [sr, cr, -sr], default=-cr)
  cos = np.select([q == 0, q == 1, q == 2], [cr, -sr, -cr], default=sr)
  return sin.astype(_F), cos.astype(_F)
def _seq_sum(x):
  """Sequential left-to-right float32 sum, mirroring a C accumulation loop
  (numpy's sum() is pairwise and rounds differently)."""
  return np.add.accumulate(x.astype(_F), dtype=_F)[-1]


def _rmsnorm(x, gamma, eps):
  x = x.astype(_F)
  ms = _seq_sum(x * x) / _F(x.shape[-1]) + _F(eps)
  inv = _F(1.0) / _F(np.sqrt(ms))
  return x * inv * (_F(1.0) + gamma.astype(_F))


def _quant_inv(x, inv):
  """Mirrors the C runtime: q = roundf(x * inv), clipped to +-127."""
  x = x.astype(np.float32)
  q = np.sign(x) * np.floor(np.abs(x) * np.float32(inv) + np.float32(0.5))
  return np.clip(q, -127, 127).astype(np.int8)


def _dyn_quant(x):
  amax = np.float32(max(np.abs(x).max(), 1e-30))
  s = amax / np.float32(127.0)
  return _quant_inv(x, np.float32(127.0) / amax), s


def _matvec_i32(wq, xq):
  return wq.astype(np.int32) @ xq.astype(np.int32)


def _rope(v, pos, log_theta):
  d = v.shape[-1]
  half = d // 2
  # Mirrors the C runtime: t = 2i/d; freq = gm_expf(-log_theta * t).
  t = (2 * np.arange(half, dtype=_F)).astype(_F) / _F(d)
  inv_freq = _gm_expf(-_F(log_theta) * t)
  ang = (_F(pos) * inv_freq).astype(_F)
  sin, cos = _gm_sincos(ang)
  x1, x2 = v[:half].astype(_F), v[half:].astype(_F)
  return np.concatenate([x1 * cos - x2 * sin, x2 * cos + x1 * sin])


def _gelu_tanh(x):
  x = x.astype(_F)
  return (_F(0.5) * x * (_F(1.0) + _gm_tanhf(
      _F(0.7978845608028654) * (x + _F(0.044715) * x * x * x)))).astype(_F)


class ReferenceModel:
  """Greedy decoding reference over the quantized model."""

  def __init__(self, c: GemmaConfig, tensors, quant):
    self.c = c
    self.t = tensors
    self.q = quant
    self.emb_scale = np.float32(quant["embedding"][1][0])
    self.kcache = [np.zeros([c.max_ctx, c.kvdim], np.int8)
                   for _ in range(c.layers)]
    self.vcache = [np.zeros([c.max_ctx, c.kvdim], np.int8)
                   for _ in range(c.layers)]
    self.pos = 0

  def _proj(self, name, xq, sx):
    wq, ws = self.q[name]
    return _matvec_i32(wq, xq).astype(np.float32) * ws * sx

  def step(self, token):
    """Runs one token; returns (next_token, logits_argmax_val, hidden)."""
    c, t = self.c, self.t
    pos = self.pos
    embq = self.q["embedding"][0]
    # Mirrors the C runtime: one combined scale factor.
    x = embq[token].astype(np.float32) * (
        self.emb_scale * np.float32(np.sqrt(np.float32(c.hidden))))
    for l in range(c.layers):
      theta = log_theta32(
          c.rope_theta_global if c.is_global(l) else c.rope_theta_local)
      resid = x
      h = _rmsnorm(x, t[f"l{l}.ln1"], c.rms_eps)
      hq, sh = _dyn_quant(h)
      qv = self._proj(f"l{l}.q", hq, sh)
      kv = self._proj(f"l{l}.k", hq, sh)
      vv = self._proj(f"l{l}.v", hq, sh)
      # QK-norm + RoPE (kv_heads == 1).
      kh = _rmsnorm(kv, t[f"l{l}.k_norm"], c.rms_eps)
      kh = _rope(kh, pos, theta)
      self.kcache[l][pos] = _quant_inv(kh, _F(1.0) / _F(c.k_scale))
      self.vcache[l][pos] = _quant_inv(vv, _F(1.0) / _F(c.v_scale))
      seqlen = pos + 1
      start = 0 if c.is_global(l) else max(0, seqlen - c.window)
      attn = np.zeros(c.qdim, np.float32)
      for hd in range(c.heads):
        qh = qv[hd * c.head_dim:(hd + 1) * c.head_dim]
        qh = _rmsnorm(qh, t[f"l{l}.q_norm"], c.rms_eps)
        qh = _rope(qh, pos, theta)
        qh = qh * np.float32(c.query_scale)
        qhq, sq = _dyn_quant(qh)
        s32 = _matvec_i32(self.kcache[l][start:seqlen], qhq)
        scores = s32.astype(np.float32) * sq * np.float32(c.k_scale)
        m = scores.max()
        e = _gm_expf((scores - m).astype(np.float32))
        norm = _F(127.0) / _seq_sum(e)
        pq = _quant_inv(e, norm)
        av32 = _matvec_i32(self.vcache[l][start:seqlen].T, pq)
        vs = (_F(1.0) / _F(127.0)) * _F(c.v_scale)  # matches C: one factor
        attn[hd * c.head_dim:(hd + 1) * c.head_dim] = (
            av32.astype(np.float32) * vs)
      aq, sa = _dyn_quant(attn)
      o = self._proj(f"l{l}.o", aq, sa)
      o = _rmsnorm(o, t[f"l{l}.post_attn_ln"], c.rms_eps)
      x = resid + o
      resid = x
      h = _rmsnorm(x, t[f"l{l}.pre_ff_ln"], c.rms_eps)
      hq, sh = _dyn_quant(h)
      gate = self._proj(f"l{l}.gate", hq, sh)
      up = self._proj(f"l{l}.up", hq, sh)
      act = _gelu_tanh(gate) * up
      actq, sact = _dyn_quant(act)
      down = self._proj(f"l{l}.down", actq, sact)
      down = _rmsnorm(down, t[f"l{l}.post_ff_ln"], c.rms_eps)
      x = resid + down
    hfinal = _rmsnorm(x, t["final_norm"], c.rms_eps)
    hquant, _ = _dyn_quant(hfinal)
    logits32 = _matvec_i32(embq, hquant)
    self.pos += 1
    return int(np.argmax(logits32)), logits32, hfinal


# =============================================================================
# Tiny random model for RTL tests.
# =============================================================================
def make_tiny(seed):
  c = GemmaConfig(hidden=64, layers=2, heads=2, kv_heads=1, head_dim=32,
                  intermediate=128, vocab=199, max_ctx=16, window=4,
                  global_period=2, query_scale=1.0 / np.sqrt(32.0))
  rng = np.random.default_rng(seed)

  def mat(r, co, scale=0.5):
    return (rng.standard_normal([r, co]) * scale).astype(np.float32)

  t = {
      # Small embedding scale keeps the input embedding from dominating the
      # residual stream (the per-tensor logit quantization is scale
      # invariant); otherwise a random tiny model just echoes its input
      # token, which would mask datapath bugs.
      "embedding": mat(c.vocab, c.hidden, 0.05),
      "final_norm": rng.uniform(-0.2, 0.5, c.hidden).astype(np.float32),
  }
  for l in range(c.layers):
    t[f"l{l}.ln1"] = rng.uniform(-0.2, 0.5, c.hidden).astype(np.float32)
    t[f"l{l}.post_attn_ln"] = rng.uniform(-0.2, 0.5, c.hidden).astype(np.float32)
    t[f"l{l}.pre_ff_ln"] = rng.uniform(-0.2, 0.5, c.hidden).astype(np.float32)
    t[f"l{l}.post_ff_ln"] = rng.uniform(-0.2, 0.5, c.hidden).astype(np.float32)
    t[f"l{l}.q_norm"] = rng.uniform(-0.2, 0.5, c.head_dim).astype(np.float32)
    t[f"l{l}.k_norm"] = rng.uniform(-0.2, 0.5, c.head_dim).astype(np.float32)
    t[f"l{l}.q"] = mat(c.qdim, c.hidden)
    t[f"l{l}.k"] = mat(c.kvdim, c.hidden)
    t[f"l{l}.v"] = mat(c.kvdim, c.hidden)
    # Strong output projections so layer contributions dominate the
    # residual stream; otherwise a random tiny model degenerates into
    # echoing its input token, which would mask datapath bugs.
    t[f"l{l}.o"] = mat(c.hidden, c.qdim, 3.0)
    t[f"l{l}.gate"] = mat(c.intermediate, c.hidden)
    t[f"l{l}.up"] = mat(c.intermediate, c.hidden)
    t[f"l{l}.down"] = mat(c.hidden, c.intermediate, 3.0)
  return c, t


def cmd_tiny(args):
  import pathlib
  outdir = pathlib.Path(args.out_dir)
  outdir.mkdir(parents=True, exist_ok=True)
  c, t = make_tiny(args.seed)
  image, quant, off = pack_model(c, t)

  ref = ReferenceModel(c, t, quant)
  prompt = [3, 17, 42, 5]
  n_gen = 4
  tokens = list(prompt)
  hiddens = []
  for i in range(len(prompt) + n_gen - 1):
    nxt, logits, hidden = ref.step(tokens[i])
    hiddens.append(hidden)
    if i >= len(prompt) - 1:
      # Require a comfortable margin so float rounding differences between
      # numpy and the on-core C runtime cannot flip the argmax.
      top2 = np.sort(logits)[-2:]
      margin = int(top2[1] - top2[0])
      assert margin >= 8, (
          f"tiny model logits margin too small ({margin}); pick another seed")
      tokens.append(nxt)

  image.tofile(outdir / "wtcm.bin")
  meta = {
      "config": dataclasses.asdict(c),
      "prompt": prompt,
      "expected_tokens": tokens[len(prompt):],
      "final_hidden": [float(v) for v in hiddens[-1]],
      "total_bytes": int(len(image)),
      "offsets": {k: int(v) for k, v in off.items()},
  }
  (outdir / "meta.json").write_text(json.dumps(meta, indent=2))
  print(f"tiny model: {len(image)} bytes, prompt {prompt} "
        f"-> {tokens[len(prompt):]}")


# =============================================================================
# HuggingFace safetensors import (no torch dependency).
# =============================================================================
def load_safetensors(path):
  with open(path, "rb") as f:
    n = struct.unpack("<Q", f.read(8))[0]
    header = json.loads(f.read(n))
    data = f.read()
  out = {}
  for name, info in header.items():
    if name == "__metadata__":
      continue
    start, end = info["data_offsets"]
    raw = data[start:end]
    if info["dtype"] == "BF16":
      u16 = np.frombuffer(raw, np.uint16).astype(np.uint32) << 16
      arr = u16.view(np.float32)
    elif info["dtype"] == "F32":
      arr = np.frombuffer(raw, np.float32)
    else:
      raise ValueError(f"unsupported dtype {info['dtype']} for {name}")
    out[name] = arr.reshape(info["shape"]).astype(np.float32)
  return out


def hf_to_canonical(c: GemmaConfig, st):
  pre = "model."
  t = {
      "embedding": st[pre + "embed_tokens.weight"],
      "final_norm": st[pre + "norm.weight"],
  }
  for l in range(c.layers):
    lp = f"{pre}layers.{l}."
    t[f"l{l}.ln1"] = st[lp + "input_layernorm.weight"]
    t[f"l{l}.post_attn_ln"] = st[lp + "post_attention_layernorm.weight"]
    t[f"l{l}.pre_ff_ln"] = st[lp + "pre_feedforward_layernorm.weight"]
    t[f"l{l}.post_ff_ln"] = st[lp + "post_feedforward_layernorm.weight"]
    t[f"l{l}.q_norm"] = st[lp + "self_attn.q_norm.weight"]
    t[f"l{l}.k_norm"] = st[lp + "self_attn.k_norm.weight"]
    t[f"l{l}.q"] = st[lp + "self_attn.q_proj.weight"]
    t[f"l{l}.k"] = st[lp + "self_attn.k_proj.weight"]
    t[f"l{l}.v"] = st[lp + "self_attn.v_proj.weight"]
    t[f"l{l}.o"] = st[lp + "self_attn.o_proj.weight"]
    t[f"l{l}.gate"] = st[lp + "mlp.gate_proj.weight"]
    t[f"l{l}.up"] = st[lp + "mlp.up_proj.weight"]
    t[f"l{l}.down"] = st[lp + "mlp.down_proj.weight"]
  return t


def cmd_hf(args):
  import glob
  import os
  c = GEMMA3_270M
  st = {}
  files = sorted(glob.glob(os.path.join(args.snapshot, "*.safetensors")))
  if not files:
    sys.exit(f"no .safetensors under {args.snapshot}")
  for f in files:
    st.update(load_safetensors(f))
  t = hf_to_canonical(c, st)
  image, _, _ = pack_model(c, t)
  image.tofile(args.out)
  print(f"packed {args.out}: {len(image)} bytes "
        f"({len(image) / (1 << 20):.1f} MiB)")


def main():
  ap = argparse.ArgumentParser()
  sub = ap.add_subparsers(dest="cmd", required=True)
  tiny = sub.add_parser("tiny", help="tiny random model for RTL tests")
  tiny.add_argument("--out-dir", required=True)
  tiny.add_argument("--seed", type=int, default=1)
  tiny.set_defaults(func=cmd_tiny)
  hf = sub.add_parser("hf", help="pack a HF gemma-3-270m snapshot")
  hf.add_argument("--snapshot", required=True)
  hf.add_argument("--out", required=True)
  hf.set_defaults(func=cmd_hf)
  args = ap.parse_args()
  args.func(args)


if __name__ == "__main__":
  main()
