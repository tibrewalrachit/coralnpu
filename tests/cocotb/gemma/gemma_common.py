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

"""Shared constants/helpers for the Gemma (WTCM + matvec engine) tests.

Memory map of the *Gemma AXI configurations (see MemoryRegions.gemma):
  ITCM  0x0000_0000
  DTCM  0x0010_0000
  CSR   0x0020_0000
  GMV   0x0030_0000  (matrix-vector engine CSRs)
  WTCM  0x4000_0000  (weight TCM)
"""

import numpy as np

DTCM_BASE = 0x00100000
CSR_BASE = 0x00200000
GMV_BASE = 0x00300000
WTCM_BASE = 0x40000000

ROW_BYTES = 256  # WTCM row size; one engine chunk

# Matrix-vector engine CSR word indices (see MatVecCsr in Gemma.scala).
GMV_CTRL = 0
GMV_STATUS = 1
GMV_W_BASE = 2
GMV_IN_BASE = 3
GMV_OUT_BASE = 4
GMV_ROWS = 5
GMV_COLS = 6
GMV_ROW_STRIDE = 7
GMV_MODE = 8
GMV_ARGMAX_IDX = 9
GMV_ARGMAX_VAL = 10
GMV_CYCLES = 11

MODE_ARGMAX = 1


def pack_rows(w: np.ndarray) -> np.ndarray:
  """Packs an int8 matrix row-major with rows padded to ROW_BYTES."""
  rows, cols = w.shape
  row_stride = ((cols + ROW_BYTES - 1) // ROW_BYTES) * ROW_BYTES
  out = np.zeros([rows, row_stride], dtype=np.int8)
  out[:, :cols] = w
  return out.reshape(-1)


def matvec_ref(w: np.ndarray, x: np.ndarray) -> np.ndarray:
  """int8 x int8 -> int32 reference."""
  return w.astype(np.int32) @ x.astype(np.int32)


async def gmv_write(core, idx: int, value: int):
  await core.write_word(GMV_BASE + 4 * idx, np.uint32(value & 0xFFFFFFFF))


async def gmv_read(core, idx: int) -> int:
  return int((await core.read_word(GMV_BASE + 4 * idx)).view(np.uint32)[0])


async def gmv_run(core, w_addr, in_addr, out_addr, rows, cols,
                  row_stride=0, mode=0, timeout=100000):
  """Programs and runs one matvec, returning the CYCLES register."""
  await gmv_write(core, GMV_W_BASE, w_addr)
  await gmv_write(core, GMV_IN_BASE, in_addr)
  await gmv_write(core, GMV_OUT_BASE, out_addr)
  await gmv_write(core, GMV_ROWS, rows)
  await gmv_write(core, GMV_COLS, cols)
  await gmv_write(core, GMV_ROW_STRIDE, row_stride)
  await gmv_write(core, GMV_MODE, mode)
  await gmv_write(core, GMV_CTRL, 1)
  for _ in range(timeout):
    status = await gmv_read(core, GMV_STATUS)
    if status & 2:  # done
      assert (status & 1) == 0
      return await gmv_read(core, GMV_CYCLES)
  raise TimeoutError("matvec engine did not complete")
