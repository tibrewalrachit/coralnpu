# Source this. Paths for the bazel-free cocotb/Verilator flow.
export CORAL_REPO="${CORAL_REPO:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
export CORAL_WORK="${CORAL_WORK:-$HOME/coral-cocotb}"
export CORAL_TC="${CORAL_TC:-$CORAL_WORK/toolchain/toolchain_kelvin_v2/bin}"   # riscv32-unknown-elf-*
export CORAL_SV="${CORAL_SV:-$CORAL_WORK/sv/coralnpu_core_mini_axi.sv}"      # flattened CoreMiniAxi bundle
export CORAL_RUNFILES="${CORAL_RUNFILES:-$CORAL_WORK/runfiles}"               # built test artifacts
export CORAL_THREADS="${CORAL_THREADS:-2}"                                     # Verilator --threads
export CORAL_JOBS="${CORAL_JOBS:-$(nproc)}"
export PATH="$HOME/miniforge3/envs/vl/bin:$PATH"                              # verilator 5.050 (setup-host.sh)
