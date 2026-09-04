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

package(default_visibility = ["//visibility:public"])

# Gemma-3 decode runtime for the Coral NPU Gemma configurations
# (weight TCM + int8 matrix-vector engine). See doc/gemma.md.
cc_library(
    name = "gemma_runtime",
    srcs = ["gemma_model.c"],
    hdrs = [
        "gemma_mmio.h",
        "gemma_model.h",
    ],
    # Decode correctness is verified token-exact against the numpy
    # reference in utils/gemma_pack.py, which requires bit-identical
    # float32 arithmetic — FMA contraction changes rounding.
    copts = ["-ffp-contract=off"],
    target_compatible_with = ["//platforms/cpu:coralnpu_v2"],
)
