#!/usr/bin/env bash
# FireMarshal host-init: build the static Linux loader into the rootfs overlay.
# Runs on the manager inside the Chipyard/FireMarshal environment, which
# provides riscv64-unknown-linux-gnu-gcc. Sources are taken from the coralnpu
# repo checkout referenced by $CORALNPU_DIR (default: sibling of chipyard).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="${CORALNPU_DIR:-$HERE/../../../../../../coralnpu}/platforms/chipyard"
[ -f "$SRC/linux/coralnpu-run.c" ] || { echo "set CORALNPU_DIR to the coralnpu checkout" >&2; exit 1; }
mkdir -p "$HERE/overlay/root"
riscv64-unknown-linux-gnu-gcc -O2 -static -Wall -I"$SRC/firmware" \
  -o "$HERE/overlay/root/coralnpu-run" "$SRC/linux/coralnpu-run.c"
riscv64-unknown-linux-gnu-strip "$HERE/overlay/root/coralnpu-run"
echo "built $HERE/overlay/root/coralnpu-run"
