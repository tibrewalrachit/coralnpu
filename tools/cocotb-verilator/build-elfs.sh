#!/usr/bin/env bash
# Build every RV32 test program tests/cocotb/core_mini_axi_sim.py loads, the
# way bazel's coralnpu_v2_binary does (fastbuild = -O1; ITCM 8K / DTCM 32K
# linker script; Coral CRT; -Wall -Werror). Output mirrors bazel runfiles
# under $CORAL_RUNFILES so the runfiles shim can find them.
set -euo pipefail
source "$(dirname "$0")/env.sh"
R=$CORAL_REPO; T=$R/tests/cocotb; OUT=$CORAL_RUNFILES/tests/cocotb; LD=$CORAL_WORK/coralnpu_tcm.ld
mkdir -p "$OUT/exceptions" "$OUT/coralnpu_isa"
sed -e 's/@@ITCM_LENGTH@@/8/' -e 's/@@DTCM_LENGTH@@/32/' -e 's/@@DTCM_ORIGIN@@/0x00010000/' -e 's/@@STACK_SIZE@@/128/' "$R/toolchain/coralnpu_tcm.ld.tpl" > "$LD"
CFLAGS=(-march=rv32imf_zve32x_zicsr_zifencei_zbb -mabi=ilp32 -mcmodel=medany -O1 -Wall -Werror -Wno-unused-function -ffunction-sections -fdata-sections -DSKIP_HTIF_SYMBOLS)
CRT=("$R/toolchain/crt/crt.S" "$R/toolchain/crt/coralnpu_start.S" "$R/toolchain/crt/coralnpu_exceptions.cc" "$R/toolchain/crt/coralnpu_gloss.cc" "$R/toolchain/crt/cxx_guards.cc")
build() { # out.elf src [extra copts]
  local out=$1 src=$2; shift 2; local tmp; tmp=$(mktemp -d); local objs=()
  for s in "$src" "${CRT[@]}"; do
    local std; case "$s" in *.cc|*.cpp) std="-std=c++17 -fno-rtti -fno-exceptions";; *.c) std=-std=gnu11;; *) std=;; esac
    "$CORAL_TC/riscv32-unknown-elf-gcc" "${CFLAGS[@]}" $std "$@" -I"$R" -c "$s" -o "$tmp/$(basename "$s").o"; objs+=("$tmp/$(basename "$s").o")
  done
  "$CORAL_TC/riscv32-unknown-elf-gcc" -march=rv32imf_zve32x_zicsr_zifencei_zbb -mabi=ilp32 -mcmodel=medany -nostdlib -nostartfiles --specs=nano.specs \
    -Wl,--gc-sections -Wl,-T,"$LD" -o "$out" "${objs[@]}" -Wl,--start-group -lstdc++ -lm -lc -lgcc -Wl,--end-group
  rm -rf "$tmp"
}
n=0
for t in align_test finish_txn_before_halt unreachable_prefetch_fault stress_test vector_store_fault; do build "$OUT/$t.elf" "$T/$t.cc"; n=$((n+1)); done
build "$OUT/float_csr_interlock_test.elf" "$T/float_csr_interlock_test.S"; n=$((n+1))
build "$OUT/frm_test.elf" "$T/frm_test.cc" -std=c++20; n=$((n+1))
for s in 0 1 2 3; do build "$OUT/wfi_slot_$s.elf" "$T/wfi_slot_$s.c"; n=$((n+1)); done
for f in "$T"/exceptions/*.cc; do build "$OUT/exceptions/$(basename "$f" .cc).elf" "$f"; n=$((n+1)); done
for f in "$T"/coralnpu_isa/*.cc; do build "$OUT/coralnpu_isa/$(basename "$f" .cc).elf" "$f"; n=$((n+1)); done
echo "built $n ELFs under $OUT"
