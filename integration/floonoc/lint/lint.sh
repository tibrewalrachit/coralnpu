#!/usr/bin/env bash
# Copyright 2025 Google LLC
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

# Verilator lint of the Coral NPU / FlooNoC mesh, using a port-accurate stub
# for the Bazel-generated CoreMiniAxi so no Bazel build is needed.
#
# Usage: ./lint.sh [workdir]   (default workdir: ./.lint_work)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLOO_DIR="$(dirname "$SCRIPT_DIR")"
WORK="${1:-$SCRIPT_DIR/.lint_work}"

# Pinned to FlooNoC master (floogen 0.8.4) and the axi/common_cells
# revisions from FlooNoC's Bender.lock.
FLOONOC_SHA=8a67b860490b3b6b82289c281f5324b287572c8a
AXI_SHA=0ccc838fe06aeeb857eb83c6be9a915c4bf99566
COMMON_CELLS_SHA=63b7c50d43e462b59506f69d341ff1e40202866d

mkdir -p "$WORK"

fetch() { # fetch <url> <dir> <sha>
  if [ ! -d "$WORK/$2" ]; then
    git init -q "$WORK/$2"
    git -C "$WORK/$2" remote add origin "$1"
  fi
  git -C "$WORK/$2" fetch -q --depth 1 origin "$3"
  git -C "$WORK/$2" checkout -q "$3"
}

fetch https://github.com/pulp-platform/FlooNoC.git      floonoc      "$FLOONOC_SHA"
fetch https://github.com/pulp-platform/axi.git          axi          "$AXI_SHA"
fetch https://github.com/pulp-platform/common_cells.git common_cells "$COMMON_CELLS_SHA"

# FlooNoC master's floo_vc_arbiter (unused here: this mesh has no virtual
# channels) pins a `credit_init_i` port that the locked common_cells
# cc_credit_counter does not have; patch it so the orphan module elaborates.
sed -i 's/\.credit_init_i    ( 1.b0                      ),/.clr_i            ( 1\x27b0                      ),/' \
  "$WORK/floonoc/hw/floo_vc_arbiter.sv"

{
  echo "$WORK/common_cells/src/cc_pkg.sv"
  ls "$WORK"/common_cells/src/deprecated/*_pkg.sv
  echo "$WORK/axi/src/axi_pkg.sv"
  echo "$WORK/floonoc/hw/floo_pkg.sv"
  echo "$FLOO_DIR/generated/floo_coralnpu_mesh_noc_pkg.sv"
  ls "$WORK"/common_cells/src/*.sv "$WORK"/common_cells/src/deprecated/*.sv | grep -v "_pkg\|_test\|assert"
  ls "$WORK"/axi/src/*.sv | grep -v "axi_pkg\|_test\|_intf\|dumper"
  ls "$WORK"/floonoc/hw/*.sv | grep -v floo_pkg
  echo "$FLOO_DIR/generated/floo_coralnpu_mesh_noc.sv"
  echo "$SCRIPT_DIR/CoreMiniAxi_stub.sv"
  echo "$FLOO_DIR/rtl/coralnpu_floo_tile.sv"
  echo "$FLOO_DIR/rtl/coralnpu_floo_mesh.sv"
} | awk '!seen[$0]++' > "$WORK/files.f"

verilator --lint-only -Wno-fatal -Wno-lint -Wno-style \
  "+incdir+$WORK/axi/include" \
  "+incdir+$WORK/common_cells/include" \
  "+incdir+$WORK/floonoc/hw/include" \
  -f "$WORK/files.f" \
  --top coralnpu_floo_mesh

echo "Lint passed."
