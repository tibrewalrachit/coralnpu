#!/usr/bin/env python3
"""Build a (tuned) Verilator model of CoreMiniAxi and run Coral's cocotb suite
without bazel, using cocotb's own runner. Runfiles (test ELFs, riscv-tests)
come from build-elfs.sh / build-riscv-tests.sh via the bazel_tools shim.

  python3 run_cocotb.py --sv <flattened CoreMiniAxi bundle> [--build-only]
         [--tests a,b,c] [--threads N] [--opt fast|default] [--seed 42]
"""
import argparse, os, sys, time, shutil
from pathlib import Path
from cocotb_tools.runner import get_runner

ap = argparse.ArgumentParser()
ap.add_argument("--sv", required=True)
ap.add_argument("--repo", default=os.environ.get("CORAL_REPO", str(Path(__file__).resolve().parents[0])))
ap.add_argument("--build-dir", default="sim_build")
ap.add_argument("--tests", default="")
ap.add_argument("--threads", type=int, default=1)
ap.add_argument("--opt", choices=["fast", "default"], default="fast")
ap.add_argument("--seed", default="42")
ap.add_argument("--build-only", action="store_true")
ap.add_argument("--no-build", action="store_true")
ap.add_argument("--jobs", type=int, default=os.cpu_count())
ap.add_argument("--results", default="", help="results XML path (default <build-dir>/results.xml)")
a = ap.parse_args()

# Flags from tests/cocotb/build_defs.bzl (VERILATOR_BUILD_ARGS) ...
base_args = ["-Wno-WIDTH", "-Wno-CASEINCOMPLETE", "-Wno-LATCH", "-Wno-SIDEEFFECT", "-Wno-MULTIDRIVEN",
             "-Wno-UNOPTFLAT", "-Wno-BLKANDNBLK", "-Wno-CASEX", "-Wno-ASCRANGE", "-Wno-WIDTHEXPAND",
             "-Wno-WIDTHTRUNC", "-Wno-UNSIGNED", "-Wno-fatal",
             "-DUSE_GENERIC=", "-DTB_SUPPORT", "-DZVE32F_ON", "-DVLEN_128"]
# ... plus the performance tuning:
tuned = ["-O3", "--x-assign", "fast", "--x-initial", "fast", "--noassert", "--assert-case",
         "-CFLAGS", "-O3 -march=native -fno-stack-protector",
         "--threads", str(a.threads), "--threads-dpi", "all"] if a.opt == "fast" else []
if a.jobs: tuned += ["--build-jobs", str(a.jobs)]

runner = get_runner("verilator")
t0 = time.time()
if not a.no_build:
    runner.build(sources=[a.sv], hdl_toplevel="CoreMiniAxi", build_dir=a.build_dir, always=True,
                 build_args=base_args + tuned, waves=False)
    print(f"[run_cocotb] verilator build: {time.time()-t0:.0f}s", flush=True)
if a.build_only: sys.exit(0)

# Runfiles roots: built artifacts first, then the source tree.
roots = [os.environ.get("CORAL_RUNFILES", str(Path(a.build_dir).resolve() / "runfiles")), a.repo]
env = {"CORAL_RUNFILES_ROOTS": ":".join(roots),
       "PYTHONPATH": ":".join([str(Path(__file__).resolve().parent / "shim"), a.repo, os.environ.get("PYTHONPATH", "")])}
tests = [t for t in a.tests.split(",") if t] or None
t1 = time.time()
runner.test(hdl_toplevel="CoreMiniAxi", test_module="core_mini_axi_sim", build_dir=a.build_dir,
            test_dir=str(Path(a.repo) / "tests" / "cocotb"), testcase=tests, seed=a.seed,
            extra_env=env, results_xml=a.results or str(Path(a.build_dir).resolve() / "results.xml"))
print(f"[run_cocotb] tests: {time.time()-t1:.0f}s", flush=True)
