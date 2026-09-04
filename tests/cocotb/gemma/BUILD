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

load("//rules:coralnpu_v2.bzl", "coralnpu_v2_binary")

package(default_visibility = ["//visibility:public"])

exports_files([
    "gemma_common.py",
    "gemma_engine_sim.py",
    "gemma_forward_sim.py",
])

py_library(
    name = "gemma_common",
    srcs = ["gemma_common.py"],
)

# On-core greedy decoding over the model image in the WTCM; driven by
# gemma_forward_sim.py. Uses the highmem TCM layout (ITCM/DTCM 1MB), which
# matches the Gemma memory map.
coralnpu_v2_binary(
    name = "gemma_forward_test",
    srcs = ["gemma_forward_test.c"],
    dtcm_size_kbytes = 1024,
    itcm_size_kbytes = 1024,
    stack_size_bytes = 8192,
    deps = ["//sw/gemma:gemma_runtime"],
)

# Tiny random Gemma-3-style model image + numpy-reference expectations for
# the RTL tests (see utils/gemma_pack.py).
genrule(
    name = "tiny_model",
    outs = [
        "tiny_model/wtcm.bin",
        "tiny_model/meta.json",
    ],
    cmd = "$(location //utils:gemma_pack) tiny --seed 1 " +
          "--out-dir $(RULEDIR)/tiny_model",
    tools = ["//utils:gemma_pack"],
)
