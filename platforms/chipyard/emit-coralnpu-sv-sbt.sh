#!/usr/bin/env bash
# Alternative to export-coralnpu-sv.sh's bazel step: emit CoreMiniAxi.sv by
# compiling Coral's Chisel with sbt (Chisel 7.0.0-RC1 from Maven Central) and
# fetching the three external SV repos with `git clone` at the SHAs pinned in
# rules/repos.bzl. Use this when bazel cannot download GitHub source archives
# (as in the authoring sandbox). Requires: git, java 17+, sbt, network to
# github.com (git) and repo1.maven.org.
#
#   ./platforms/chipyard/emit-coralnpu-sv-sbt.sh [work dir]   (default: build/coralnpu-sbt)
#   then: ./platforms/chipyard/export-coralnpu-sv.sh --from-dir <work dir>/emit [out dir]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
WORK="${1:-$ROOT/build/coralnpu-sbt}"
mkdir -p "$WORK/ext" "$WORK/res/external" "$WORK/proj/project" "$WORK/proj/src/main/scala" "$WORK/emit"

pin() {  # repo sha
  local name="${1#*/}"
  if [ ! -d "$WORK/ext/$name/.git" ]; then
    git clone -q --filter=blob:none --no-checkout "https://github.com/$1.git" "$WORK/ext/$name"
    git -C "$WORK/ext/$name" fetch -q --depth 1 origin "$2"
    git -C "$WORK/ext/$name" checkout -q "$2"
  fi
}
# SHAs from rules/repos.bzl (cvfpu_repos)
pin openhwgroup/cvfpu              58ca3c376beb914b2b80b811d4b270c063d4e6f7
pin pulp-platform/common_cells     6aeee85d0a34fedc06c14f04fd6363c9f7b4eeea
pin pulp-platform/fpu_div_sqrt_mvp 86e1f558b3c95e91577c41b2fc452c86b04e85ac
for p in "$ROOT"/third_party/cvfpu/*.patch; do
  git -C "$WORK/ext/cvfpu" apply --check "$p" 2>/dev/null && git -C "$WORK/ext/cvfpu" apply "$p" && echo "applied $(basename "$p")" || true
done
# Resource layout mirrors bazel's runfiles: external/<repo>/..., hdl/...; plus
# hdl/verilog at the root for ClockGate.sv / RstSync.sv (resource_strip_prefix).
ln -sfn "$WORK/ext/cvfpu"            "$WORK/res/external/cvfpu"
ln -sfn "$WORK/ext/common_cells"     "$WORK/res/external/common_cells"
ln -sfn "$WORK/ext/fpu_div_sqrt_mvp" "$WORK/res/external/fpu_div_sqrt_mvp"
ln -sfn "$ROOT/hdl"                  "$WORK/res/hdl"

REV="$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || printf 'f%.0s' $(seq 40))"
printf 'package coralnpu\n\nclass ScmInfo {\n    val revision = BigInt("%s", 16)\n}\n' "$REV" > "$WORK/proj/src/main/scala/ScmInfo.scala"
echo "sbt.version=1.10.7" > "$WORK/proj/project/build.properties"
cat > "$WORK/proj/build.sbt" <<SBT
ThisBuild / scalaVersion := "2.13.16"
lazy val root = (project in file("."))
  .settings(
    name := "coral-emit",
    libraryDependencies += "org.chipsalliance" %% "chisel" % "7.0.0-RC1",
    addCompilerPlugin("org.chipsalliance" % "chisel-plugin" % "7.0.0-RC1" cross CrossVersion.full),
    Compile / unmanagedSourceDirectories := Seq(
      file("$WORK/proj/src/main/scala"),
      file("$ROOT/hdl/chisel/src/bus"),
      file("$ROOT/hdl/chisel/src/common"),
      file("$ROOT/hdl/chisel/src/coralnpu")),
    // tests need scalatest/chiseltest; the three bus files need rocket-chip
    Compile / excludeFilter := HiddenFileFilter || "*Test.scala" || "TlulFifoAsync.scala" || "Spi2TLUL.scala" || "SpiMaster.scala",
    Compile / unmanagedResourceDirectories := Seq(file("$WORK/res"), file("$ROOT/hdl/verilog")),
    scalacOptions ++= Seq("-deprecation", "-feature", "-language:reflectiveCalls"),
    Compile / run / fork := true,
    Compile / run / javaOptions ++= Seq("-Xmx6G", "-Xss64m"))
SBT
cd "$WORK/proj"
# Same flags as //hdl/chisel/src/coralnpu:core_mini_axi_cc_library
sbt -Dsbt.server.forcestart=false "runMain coralnpu.EmitCore --target-dir=$WORK/emit --enableFetchL0=False --fetchDataBits=128 --lsuDataBits=128 --enableFloat=True --moduleName=CoreMini --useAxi"
ls -la "$WORK/emit/CoreMiniAxi.sv" "$WORK/emit/CoreMiniAxi.zip"
echo "next: $ROOT/platforms/chipyard/export-coralnpu-sv.sh --from-dir $WORK/emit"
