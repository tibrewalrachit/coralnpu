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

"""End-to-end Gemma decode test on CoreMiniGemmaAxi.

Loads a tiny random Gemma-3-style model image (utils/gemma_pack.py tiny)
into the WTCM, runs the on-core runtime (sw/gemma) for a few greedy decode
steps, and checks generated tokens and the final hidden state against the
numpy reference baked into meta.json.

Environment:
  GEMMA_TINY_DIR: directory containing wtcm.bin + meta.json
  GEMMA_FORWARD_ELF: path to gemma_forward_test ELF
"""

import json
import os
import pathlib

import cocotb
import numpy as np

from coralnpu_test_utils.sim_test_fixture import Fixture
from tests.cocotb.gemma.gemma_common import WTCM_BASE


def _tiny_dir():
  d = os.environ.get("GEMMA_TINY_DIR")
  if d:
    return pathlib.Path(d)
  raise RuntimeError("GEMMA_TINY_DIR not set")


def _elf_path():
  p = os.environ.get("GEMMA_FORWARD_ELF")
  if p:
    return p
  raise RuntimeError("GEMMA_FORWARD_ELF not set")


@cocotb.test(timeout_time=1200, timeout_unit="sec")
async def gemma_tiny_forward(dut):
  tiny = _tiny_dir()
  meta = json.loads((tiny / "meta.json").read_text())
  image = np.fromfile(tiny / "wtcm.bin", dtype=np.uint8)

  fixture = await Fixture.Create(dut, csr_base_addr=0x200000)
  core = fixture.core_mini_axi

  dut._log.info("loading %d byte model image into WTCM", len(image))
  await core.write(WTCM_BASE, image)

  await fixture.load_elf_and_lookup_symbols(
      _elf_path(),
      ["prompt_tokens", "prompt_len", "gen_len", "generated_tokens",
       "final_hidden", "test_status", "decode_cycles"])

  prompt = np.array(meta["prompt"], dtype=np.uint32)
  expected = meta["expected_tokens"]
  await fixture.write("prompt_tokens", prompt.view(np.uint8))
  await fixture.write("prompt_len",
                      np.array([len(prompt)], np.uint32).view(np.uint8))
  await fixture.write("gen_len",
                      np.array([len(expected)], np.uint32).view(np.uint8))

  await fixture.run_to_halt(timeout_cycles=50_000_000)

  status = (await fixture.read("test_status", 4)).view(np.uint32)[0]
  assert status == 1, f"on-core runtime failed, test_status={status}"

  tokens = (await fixture.read(
      "generated_tokens", 4 * len(expected))).view(np.uint32)
  assert list(tokens) == expected, f"{list(tokens)} != {expected}"

  hidden = np.array(meta["final_hidden"], dtype=np.float32)
  got = (await fixture.read("final_hidden", 4 * len(hidden))).view(np.float32)
  np.testing.assert_allclose(got, hidden, rtol=2e-2, atol=2e-2)

  cycles = (await fixture.read("decode_cycles", 4)).view(np.uint32)[0]
  steps = len(prompt) + len(expected) - 1
  dut._log.info("decode: %d cycles for %d steps (%d cycles/token)",
                cycles, steps, cycles // steps)
