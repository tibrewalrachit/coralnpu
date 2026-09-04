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

"""Host-driven tests for the Gemma weight TCM and matrix-vector engine.

These tests drive the CoreMiniGemmaAxi top-level entirely over the AXI
slave port (the RISC-V core stays in reset), verifying the WTCM and the
engine datapath bit-exactly against numpy.
"""

import cocotb
import numpy as np

from coralnpu_test_utils.core_mini_axi_interface import CoreMiniAxiInterface
from tests.cocotb.gemma.gemma_common import (
    DTCM_BASE, WTCM_BASE, ROW_BYTES,
    GMV_ARGMAX_IDX, GMV_ARGMAX_VAL, MODE_ARGMAX,
    pack_rows, matvec_ref, gmv_run,
)


async def _make_core(dut):
  core = CoreMiniAxiInterface(dut, csr_base_addr=0x200000)
  await core.init()
  await core.reset()
  cocotb.start_soon(core.clock.start())
  return core


@cocotb.test()
async def gemma_wtcm_write_read(dut):
  """Bytes written to the WTCM over AXI read back identically."""
  core = await _make_core(dut)
  rng = np.random.default_rng(1)
  for offset in [0, ROW_BYTES, 12345 & ~0xF, 0x10000]:
    data = rng.integers(0, 256, 512, dtype=np.uint8)
    await core.write(WTCM_BASE + offset, data)
    readback = (await core.read(WTCM_BASE + offset, len(data))).astype(np.uint8)
    assert (readback == data).all(), f"WTCM mismatch at offset {offset:#x}"


@cocotb.test()
async def gemma_matvec_int8(dut):
  """Engine matvec output matches numpy exactly, incl. partial chunks."""
  core = await _make_core(dut)
  rng = np.random.default_rng(2)
  for rows, cols in [(4, 256), (7, 40), (16, 640), (3, 2048), (1, 1), (5, 257)]:
    w = rng.integers(-128, 128, [rows, cols], dtype=np.int8)
    x = rng.integers(-128, 128, cols, dtype=np.int8)
    w_addr = WTCM_BASE
    in_addr = DTCM_BASE
    out_addr = DTCM_BASE + 0x8000
    await core.write(w_addr, pack_rows(w).view(np.uint8))
    await core.write(in_addr, x.view(np.uint8))
    cycles = await gmv_run(core, w_addr, in_addr, out_addr, rows, cols)
    out = (await core.read(out_addr, 4 * rows)).view(np.int32)
    expected = matvec_ref(w, x)
    assert (out == expected).all(), (
        f"matvec mismatch rows={rows} cols={cols}: {out} != {expected}")
    dut._log.info("matvec rows=%d cols=%d took %d engine cycles",
                  rows, cols, cycles)


@cocotb.test()
async def gemma_matvec_argmax(dut):
  """Argmax mode tracks the max row without writing outputs."""
  core = await _make_core(dut)
  rng = np.random.default_rng(3)
  rows, cols = 64, 96
  w = rng.integers(-128, 128, [rows, cols], dtype=np.int8)
  x = rng.integers(-128, 128, cols, dtype=np.int8)
  await core.write(WTCM_BASE, pack_rows(w).view(np.uint8))
  await core.write(DTCM_BASE, x.view(np.uint8))
  await gmv_run(core, WTCM_BASE, DTCM_BASE, 0, rows, cols, mode=MODE_ARGMAX)
  expected = matvec_ref(w, x)
  idx = (await core.read_word(0x00300000 + 4 * GMV_ARGMAX_IDX)).view(np.uint32)[0]
  val = (await core.read_word(0x00300000 + 4 * GMV_ARGMAX_VAL)).view(np.int32)[0]
  assert idx == int(np.argmax(expected)), f"{idx} != {np.argmax(expected)}"
  assert val == expected[int(idx)], f"{val} != {expected[int(idx)]}"


@cocotb.test()
async def gemma_matvec_strided(dut):
  """ROW_STRIDE decouples row pitch from row length (V^T layouts)."""
  core = await _make_core(dut)
  rng = np.random.default_rng(4)
  rows, cols, stride_rows = 8, 100, 4  # 1KB pitch, 100-byte rows
  w = rng.integers(-128, 128, [rows, cols], dtype=np.int8)
  x = rng.integers(-128, 128, cols, dtype=np.int8)
  buf = np.zeros(rows * stride_rows * ROW_BYTES, dtype=np.int8)
  for r in range(rows):
    base = r * stride_rows * ROW_BYTES
    buf[base:base + cols] = w[r]
  await core.write(WTCM_BASE, buf.view(np.uint8))
  await core.write(DTCM_BASE, x.view(np.uint8))
  out_addr = DTCM_BASE + 0x8000
  await gmv_run(core, WTCM_BASE, DTCM_BASE, out_addr, rows, cols,
                row_stride=stride_rows)
  out = (await core.read(out_addr, 4 * rows)).view(np.int32)
  expected = matvec_ref(w, x)
  assert (out == expected).all(), f"{out} != {expected}"


@cocotb.test()
async def gemma_matvec_back_to_back(dut):
  """The engine is reusable without reset between operations."""
  core = await _make_core(dut)
  rng = np.random.default_rng(5)
  cols = 128
  x = rng.integers(-128, 128, cols, dtype=np.int8)
  await core.write(DTCM_BASE, x.view(np.uint8))
  for i in range(3):
    rows = 4 + i
    w = rng.integers(-128, 128, [rows, cols], dtype=np.int8)
    await core.write(WTCM_BASE, pack_rows(w).view(np.uint8))
    out_addr = DTCM_BASE + 0x8000
    await gmv_run(core, WTCM_BASE, DTCM_BASE, out_addr, rows, cols)
    out = (await core.read(out_addr, 4 * rows)).view(np.int32)
    assert (out == matvec_ref(w, x)).all()
