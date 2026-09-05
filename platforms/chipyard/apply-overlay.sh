#!/usr/bin/env bash
# Copy the Chipyard-side files into a Chipyard checkout and register the
# bare-metal test. Idempotent. Usage: ./apply-overlay.sh $CY_DIR
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
CY="${1:?usage: apply-overlay.sh <chipyard dir>}"
[ -f "$CY/build.sbt" ] || { echo "not a chipyard checkout: $CY" >&2; exit 1; }
cp -v "$HERE/overlay/chipyard/generators/chipyard/src/main/scala/example/CoralNPU.scala" \
      "$CY/generators/chipyard/src/main/scala/example/CoralNPU.scala"
cp -v "$HERE/overlay/chipyard/generators/chipyard/src/main/scala/config/CoralNPUConfigs.scala" \
      "$CY/generators/chipyard/src/main/scala/config/CoralNPUConfigs.scala"
cp -v "$HERE/overlay/chipyard/generators/firechip/chip/src/main/scala/CoralNPUTargetConfigs.scala" \
      "$CY/generators/firechip/chip/src/main/scala/CoralNPUTargetConfigs.scala"
cp -v "$HERE/overlay/chipyard/tests/coralnpu.c" "$CY/tests/coralnpu.c"
cp -v "$HERE/firmware/coralnpu_fw.h" "$CY/tests/coralnpu_fw.h"
if ! grep -q "add_executable(coralnpu coralnpu.c)" "$CY/tests/CMakeLists.txt"; then
  sed -i 's/^add_executable(gcd gcd.c)$/add_executable(gcd gcd.c)\nadd_executable(coralnpu coralnpu.c)/' "$CY/tests/CMakeLists.txt"
  sed -i 's/^add_dump_target(gcd)$/add_dump_target(gcd)\nadd_dump_target(coralnpu)/' "$CY/tests/CMakeLists.txt"
  echo "registered tests/coralnpu in $CY/tests/CMakeLists.txt"
fi
echo "overlay applied. Set CORALNPU_SV=<abs path to coralnpu_core_mini_axi.sv> before elaborating."
