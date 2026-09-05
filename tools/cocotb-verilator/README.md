# Coral NPU cocotb suite on a tuned Verilator, without bazel (local or AWS)

Runs `tests/cocotb/core_mini_axi_sim.py` (the `core_mini_axi_sim_cocotb`
suite, 16 test cases) against `CoreMiniAxi` using cocotb's own runner and a
Verilator 5.050 model built with performance flags. Needed where bazel cannot
fetch GitHub source archives, and as a self-contained recipe for an EC2 box.

| Script | What |
|---|---|
| `env.sh` | paths (`CORAL_WORK`, toolchain, SV bundle, runfiles, threads) |
| `setup-host.sh` | Miniforge + conda env `vl` (verilator 5.050, ccache, sbt, jdk), pip cocotb 2.x, Coral RV32 toolchain tarball, CoreMiniAxi SV via the sbt route |
| `build-elfs.sh` | the 21 RV32 test programs, built like `coralnpu_v2_binary` (fastbuild, ITCM 8K/DTCM 32K script, Coral CRT) |
| `build-riscv-tests.sh` | riscv-tests rv32ui/um/uzbb/uf at Coral's pinned commit with Coral's `env/` and linker script |
| `run_cocotb.py` | cocotb runner: verilate (tuned) + run test cases; `shim/` fakes `bazel_tools...runfiles` |
| `run-all.sh` | everything above, then N test cases in parallel, then a PASS/FAIL table from the JUnit XML |
| `aws/launch.py`, `aws/user-data.sh` | boto3 launcher: Ubuntu 24.04 instance, SSM role, sshd on 443, runs `run-all.sh` unattended |

## Verilator tuning (vs `tests/cocotb/build_defs.bzl` defaults)

`run_cocotb.py --opt fast` adds, on top of Coral's `VERILATOR_BUILD_ARGS`:

```
-O3 --x-assign fast --x-initial fast --noassert --assert-case
-CFLAGS "-O3 -march=native -fno-stack-protector"
--threads $CORAL_THREADS --threads-dpi all --build-jobs $CORAL_JOBS
```

Notes: `--noassert` drops the design's `assert`s (the bazel flow keeps them);
use `--opt default` for a like-for-like run. `--threads 2` is the sweet spot for
this ~115-module design; more threads mostly add sync overhead. Parallelism
across test cases (`run-all.sh --parallel N`) is what uses a big instance.

## Local

```bash
tools/cocotb-verilator/run-all.sh --parallel 2 --threads 2      # full flow
tools/cocotb-verilator/run-all.sh --skip-setup --skip-build --tests core_mini_axi_frm_test
```

## AWS (costs money; the launcher does not ask)

```bash
export AWS_ACCESS_KEY_ID=... AWS_SECRET_ACCESS_KEY=...
python3 tools/cocotb-verilator/aws/launch.py --region us-east-1 --type c7i.8xlarge --parallel 8 --threads 2
python3 tools/cocotb-verilator/aws/launch.py --region us-east-1 --status i-...      # tail log + results (SSM)
python3 tools/cocotb-verilator/aws/launch.py --region us-east-1 --terminate i-...
```

Results: `~/coral-cocotb/results/<test>.xml|log` on the instance,
`~/coral-cocotb-run.log` for the whole run.

## Known deviations from the bazel flow

- cocotb 2.1 (pip) instead of the pinned 2.0.0 wheel; Verilator 5.050 instead of
  bazel's pinned build.
- `-O0` test programs like bazel fastbuild; `-u _printf_float` (bazel feature
  `printf_float`) is off because it does not fit ITCM.
- `core_mini_axi_riscv_dv` uses the checked-in `tests/cocotb/riscv-dv/*.o`.
