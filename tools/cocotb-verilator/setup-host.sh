#!/usr/bin/env bash
# One-time host setup for the bazel-free cocotb flow (Ubuntu/Debian or any
# Linux with curl + git + gcc). Everything lands in user space:
#   ~/miniforge3           conda; env "vl" = verilator 5.050, ccache, sbt, openjdk
#   ~/.local               cocotb 2.x, pyelftools, numpy, tqdm (pip --user)
#   $CORAL_WORK/toolchain  Coral RV32 toolchain (same tarball bazel fetches)
#   $CORAL_WORK/sv         CoreMiniAxi.sv bundle (sbt route, no bazel needed)
set -euo pipefail
source "$(dirname "$0")/env.sh"
mkdir -p "$CORAL_WORK"
if [ ! -x "$HOME/miniforge3/bin/conda" ]; then
  curl -sSL -o /tmp/miniforge.sh https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh
  bash /tmp/miniforge.sh -b -p "$HOME/miniforge3"; rm -f /tmp/miniforge.sh
fi
source "$HOME/miniforge3/etc/profile.d/conda.sh"
[ -d "$HOME/miniforge3/envs/vl" ] || conda create -y -q -n vl -c conda-forge "verilator=5.050" ccache sbt openjdk=17 "python=3.11"
python3 -m pip install --user -q "cocotb==2.0.0" pyelftools numpy tqdm   # 2.0.0: Coral pins it; 2.1 changes handle types (PackedObject)
if [ ! -x "$CORAL_TC/riscv32-unknown-elf-gcc" ]; then
  mkdir -p "$CORAL_WORK/toolchain"
  curl -sSL https://storage.googleapis.com/shodan-public-artifacts/toolchain_kelvin_tar_files/toolchain_kelvin_v2-2025-09-11.tar.gz | tar xz -C "$CORAL_WORK/toolchain"
fi
if [ ! -s "$CORAL_SV" ]; then
  conda activate vl
  "$CORAL_REPO/platforms/chipyard/emit-coralnpu-sv-sbt.sh" "$CORAL_WORK/sbt"
  "$CORAL_REPO/platforms/chipyard/export-coralnpu-sv.sh" --from-dir "$CORAL_WORK/sbt/emit" "$CORAL_WORK/sv"
fi
verilator --version; python3 -c "import cocotb; print('cocotb', cocotb.__version__)"; "$CORAL_TC/riscv32-unknown-elf-gcc" --version | head -1
echo "setup done: CORAL_WORK=$CORAL_WORK"
