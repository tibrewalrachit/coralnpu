#!/usr/bin/env bash
# Build riscv-tests rv32{ui,um,uzbb,uf} as third_party/riscv-tests/BUILD.bazel
# does (pinned commit, Coral's env/ and linker script), into $CORAL_RUNFILES.
set -euo pipefail
source "$(dirname "$0")/env.sh"
R=$CORAL_REPO; W=$CORAL_WORK; SRC=$W/riscv-tests; ENV=$W/riscv-env
if [ ! -d "$SRC/.git" ]; then
  git clone -q --filter=blob:none --no-checkout https://github.com/riscv-software-src/riscv-tests.git "$SRC"
  git -C "$SRC" fetch -q --depth 1 origin fd4e6cdd033d9075632be9dd207c848181ca474c
  git -C "$SRC" checkout -q fd4e6cdd033d9075632be9dd207c848181ca474c
  git -C "$SRC" apply "$R/third_party/riscv-tests/0001-Find-env-from-environment.patch"
fi
mkdir -p "$ENV/p" "$ENV/v"
cp "$R/third_party/riscv-tests/env/p/riscv_test.h" "$ENV/p/"; cp "$R"/third_party/riscv-tests/env/v/{entry.S,riscv_test.h,vm.c} "$ENV/v/"
[ -s "$W/coralnpu_tcm.ld" ] || "$(dirname "$0")/build-elfs.sh" >/dev/null
cp "$W/coralnpu_tcm.ld" "$ENV/p/link.ld"; cp "$W/coralnpu_tcm.ld" "$ENV/v/link.ld"
cd "$SRC"; export PATH="$CORAL_TC:$PATH"
[ -f configure ] || autoconf; [ -f Makefile ] || ./configure --prefix="$W/riscv-tests-install" >/dev/null
OUT=$CORAL_RUNFILES/third_party/riscv-tests
for sub in ui um uzbb uf; do
  make -C isa -j"$CORAL_JOBS" XLEN=32 RISCV_PREFIX=riscv32-unknown-elf- RISCV_GCC_OPTS="-march=rv32imf_zve32x_zicsr_zifencei_zbb -mabi=ilp32 -mcmodel=medany -nostdlib" RISCV_ENV_DIR="$ENV" "rv32$sub" > "$W/riscv-tests-$sub.log" 2>&1
  D=$OUT/copy_riscv_tests_rv32$sub/riscv_tests_rv32$sub/isa; mkdir -p "$D"; cp isa/rv32$sub-p-* "$D/"; cp isa/rv32$sub-v-* "$D/" 2>/dev/null || true
  echo "rv32$sub: $(ls "$D" | grep -vc dump) ELFs"
done
