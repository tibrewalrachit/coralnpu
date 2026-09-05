# Bring-up log: CVA6 + Coral NPU on FireSim / AWS F2

Chronological. Every state-mutating command is recorded with its outcome.
Each phase ends with a `CHECKPOINT` line.

## Phase 0 — Inventory (2026-09-05)

### 0.1 Where am I actually running?

| Probe | Result |
|---|---|
| Host | `vm`, Ubuntu 24.04.4 LTS, x86_64, 4 vCPU, 15 GB RAM, 30 GB free disk |
| FireSim manager / FPGA Developer AMI? | **No.** No `/home/centos`, no `/opt/Xilinx`, no `firesim`, no `aws` CLI, no conda |
| EC2 instance metadata | Unreachable (not an EC2 instance) |
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` env vars | Set, but `sts:GetCallerIdentity` returns `InvalidClientTokenId` — placeholders, not usable |
| Vivado | Absent |
| Verilator / VCS | Absent |
| RISC-V toolchains (rv32 elf, rv64 elf, rv64 linux) | Absent |
| bazel / bazelisk | Absent (installed bazelisk to `~/bin`, see 0.4) |
| sbt / scala | Absent |
| gcc 13.3 / clang 18 / python 3.11.15 / pip 24 / docker 29 / git 2.43 | Present |
| Outbound network | Only via the session proxy. `git clone` of github.com works. GitHub **release** downloads work. GitHub **source archive** URLs (`/archive/*.zip`, `codeload.github.com`) return **403**. `storage.googleapis.com` and Maven Central reach fine. |

Conclusion: this session is a sandboxed container, not the FireSim manager instance
the plan assumes. Everything that needs AWS, Vivado, VCS, or conda-managed
toolchains cannot run here. See the checkpoint at the end of this phase.

### 0.2 State-mutating commands run

| # | Command | Outcome |
|---|---|---|
| 1 | `git checkout claude/cva6-coral-firesim-f2-ob5gdg` (branch pre-existed on origin, tracks `main` at `98ffe39`) | OK |
| 2 | `git clone --depth 1 --branch 1.21.0 https://github.com/firesim/firesim.git` (scratchpad, no submodules) | OK, HEAD `da2a1cb` |
| 3 | `git clone --depth 1 --branch 1.14.0 https://github.com/ucb-bar/chipyard.git` (scratchpad, no submodules) | OK, HEAD `0acc1e1` |
| 4 | `git clone --filter=blob:none --no-checkout https://github.com/ucb-bar/cva6-wrapper.git` + sparse checkout of `chipyard/` at `187ed3cd` (Chipyard 1.14.0 pin) | OK |
| 5 | `curl -L .../bazelisk-linux-amd64 -o ~/bin/bazelisk` (user-space, no system packages) | OK, bazelisk v1.29.0 |
| 6 | `pip install --user boto3` (only to run the read-only STS identity check) | OK |
| 7 | `bazel query 'kind(".*", //hdl/chisel/src/coralnpu:all)'` in this repo | **FAILED**: fetch of `@rules_proto` from `github.com/bazelbuild/rules_proto/archive/<sha>.zip` → HTTP 403 from the proxy |
| 8 | Re-check of the same URL and `codeload.github.com` with `curl` | **FAILED again (403)**. Two consecutive failures → stopped per rule 4. Not attempting a mirror/workaround without asking. |

### 0.3 FireSim / Chipyard inventory

| Item | Value |
|---|---|
| FireSim latest release | **1.21.0** (tag), commit `da2a1cb` |
| Platforms shipped | `f1`, **`f2`**, `xilinx_alveo_u200/u250/u280`, `xilinx_vcu118`, `rhsresearch_nitefury_ii`, `vitis` |
| F2 shell repo / pin | submodule `platforms/f2/aws-fpga-firesim-f2` @ `80b34d3c25aff03353c0b4f2d304bb6067a5011d` = head of branch `bump-upstream` (PR #4) of `firesim/aws-fpga-firesim-f2`. No tag. F2 build uses `aws_build_dcp_from_cl.py --mode small_shell`, clock recipe A1/B0/C0. **Use exactly this submodule commit; do not mix with `platforms/f1/aws-fpga` (`53223d7`).** |
| F2 bit builder | `deploy/bit-builder-recipes/f2.yaml` → `F2BitBuilder`, needs an S3 bucket (`s3_bucket_name: firesim`, user+region appended) |
| Build farm default | `z1d.2xlarge` on-demand per build (`deploy/build-farm-recipes/aws_ec2.yaml`); docs: 2–6 h per bitstream, larger instances give diminishing returns |
| Run farm default | `AWSEC2F2`, `f2.6xlarge: 1` (1 FPGA) (`deploy/run-farm-recipes/aws_ec2.yaml`) |
| Chipyard pinned by FireSim 1.21.0 | Chipyard **1.14.0** (`0acc1e1`) — its `sims/firesim` submodule points back at `da2a1cb`, so the pair is consistent |
| CVA6 generator | `generators/cva6` = `ucb-bar/cva6-wrapper` @ `187ed3cd` |
| CVA6 config names | `chipyard.CVA6Config` = `cva6.WithNCVA6Cores(1) ++ AbstractConfig`; `chipyard.dmiCVA6Config`; FireSim target **`FireSimCVA6Config`** = `WithDefaultFireSimBridges ++ WithFireSimConfigTweaks ++ chipyard.CVA6Config` (`generators/firechip/chip/src/main/scala/TargetConfigs.scala:310`) |
| CVA6 software-sim support | Chipyard docs (`docs/Generators/CVA6.rst`): **"This target does not support Verilator simulation at this time. Please use VCS."** Also: single-core only (AXI, non-coherent). |
| Pre-built F2 AGFI for CVA6 | **None.** `sample_config_hwdb.yaml` in 1.21.0 contains only a placeholder `midasexamples_gcd` with an invalid URL. The AGFI IDs in the docs are Rocket examples. Baseline CVA6 bitstream must be built. |
| AXI4 blackbox reference pattern | `generators/chipyard/src/main/scala/example/GCD.scala` (`GCDAXI4` + `WithGCD(useAXI4=true, useBlackBox=true)`; `pbus.coupleTo` with `TLToAXI4 := TLFragmenter(holdFirstDeny=true)`), `example/InitZero.scala` (`fbus.coupleFrom` client-side), Verilog resources in `generators/chipyard/src/main/resources/vsrc/` |
| Bare-metal test dir | `chipyard/tests/*.c` with CMake (`tests/CMakeLists.txt`, e.g. `gcd.c`) |

### 0.4 Coral NPU inventory (this repo, `98ffe39`)

| Item | Value |
|---|---|
| Build system | Bazel **7.4.1** (`.bazelversion`), WORKSPACE-based (no MODULE.bazel). Needs Python 3.9–3.12 and SRecord (`srec_cat`, absent here) |
| RISC-V toolchain | Hermetic, fetched by bazel: `toolchain_kelvin_v2-2025-09-11.tar.gz` from `storage.googleapis.com` (reachable). Default `-march=rv32imf_zve32x_zicsr_zifencei_zbb`, no `c` (matches the pitfall note) |
| SV generation target | `//hdl/chisel/src/coralnpu:core_mini_axi_cc_library` (template in `hdl/chisel/src/coralnpu/BUILD:447`), emits `CoreMiniAxi.sv` + `CoreMiniAxi.zip`, flags `--enableFetchL0=False --fetchDataBits=128 --lsuDataBits=128 --enableFloat=True --moduleName=CoreMini --useAxi`. RVV variant: `rvv_core_mini_axi_cc_library` |
| Top module | `CoreMiniAxi` (`CoreAxi.scala`, RawModule). Ports: `aclk`, `aresetn` (async, active-low), `axi_slave` (ITCM/DTCM/CSR), `axi_master`, `halted`, `fault`, `wfi` (out), `irq`, `boot_addr[31:0]`, `te` (in), `debug`, `dm` (debug module) |
| AXI widths (both ports) | **ID = 6, ADDR = 32, DATA = 128** (`axi2IdBits=6`, `axi2DataBits = lsuDataBits = 128`). Master read-data demux uses ID 0 (data) / ID 1 (fetch): the SoC side must return the same ID it was given |
| Slave memory map (default, used by `core_mini_axi`) | ITCM `0x0000_0000` +8 KB; DTCM `0x0001_0000` +32 KB; CSR `0x0003_0000` +4 KB (`Parameters.scala` `MemoryRegions.default`) |
| CSR block (`CoreAxiCSR.scala`) | `+0x0` reset reg: bit0 = core reset (active high), bit1 = clock gate; **resets to 3** (held in reset, clock gated). `+0x4` PC_START (loaded from `boot_addr` on reset). `+0x8` status: bit0 = halted, bit1 = fault. `+0x800..0x814` debug-module request/response regs |
| `stall` port | **Does not exist** on `CoreMiniAxi`. The equivalent is the CSR reset register: bit1 (clock gate) is the "stall", bit0 the reset. Plan's "stall + reset controllable from MMIO" is therefore satisfied by the IP's own CSR at `+0x30000`; no extra control block needed |
| Reference load/run sequence (`coralnpu_test_utils/core_mini_axi_interface.py`) | 1. pulse `aresetn` → CSR reset reg = 3. 2. AXI-write ITCM/DTCM. 3. write PC_START (`0x30004`). 4. write reset reg = 1 (ungate clock, keep reset). 5. write reset reg = 0 (release reset). 6. poll status (`0x30008`) bit0 for `halted` |
| Existing FPGA/SoC glue | `fpga/` (fusesoc/Vivado Nexus flow), `hw_sim/core_mini_axi_wrapper` (Verilator C++ wrapper) — useful as reference, not reused |
| `bazel` here | bazelisk installed; workspace fetch **blocked** by proxy 403 on GitHub source archives (see 0.2 #7–8). SV cannot be generated in this container. |

### CHECKPOINT (end of Phase 0)

- **Works:** repo cloned on the target branch; FireSim 1.21.0 / Chipyard 1.14.0 / cva6-wrapper facts recorded; Coral NPU interface, widths, memory map, CSR map and run sequence recorded from source; bazelisk present.
- **Doesn't work:** bazel SV generation (proxy blocks `github.com/*/archive/*.zip`, failed twice); no Verilator, no RISC-V toolchains, no conda, no Vivado, no VCS, no valid AWS credentials.
- **Blocking:** this is not the FireSim manager instance. Phases 1, 4, 5 (managerinit, bitstream builds, F2 runs) and the Verilator/VCS boots cannot be executed here. Phase 2/3 source work (blackbox wrapper, config fragment, bare-metal test, Linux loader, FireMarshal workload) can be written here but not compiled or simulated. Additional risk: Chipyard docs state CVA6 is VCS-only (no Verilator), so Phase 1's Verilator boot needs a VCS license on the manager or a Rocket-based smoke test instead.

## Phase 0b — Can this container drive AWS at all? (after user: "aws login when needed, ask for creds")

| Probe | Result |
|---|---|
| Outbound TCP 22 (github.com:22) | **BLOCKED** → cannot ssh to a manager or build/run farm hosts on port 22 |
| Outbound TCP 443 to arbitrary hosts (1.1.1.1:443) | **OPEN** (direct, not via proxy) |
| `ec2.*`, `ssm.*`, `s3.amazonaws.com` APIs | reachable |
| conda-forge repodata / Miniforge release | reachable (200) |
| session-manager-plugin download | reachable (200) |

Consequence: with valid credentials this container can launch a manager
instance via the EC2 API and reach it over **443** (user-data adds `Port 443`
to sshd, or SSM Session Manager). The FireSim manager itself must run on that
EC2 instance; it cannot run here. Nothing costing money has been done.

## Phase 2 — Coral NPU as a Chipyard peripheral (source work, no simulation)

All files under `platforms/chipyard/` (see its README). Facts they rest on
were read from Chipyard 1.14.0, rocket-chip `55bcad0`, cva6-wrapper `187ed3cd`,
FireSim 1.21.0 and this repo's `CoreAxi.scala` / `CoreAxiCSR.scala` /
`bus/Axi.scala`.

| # | Item | Outcome |
|---|---|---|
| 1 | `CoralNPU.scala`: blackbox with Coral's exact port names (`io_axi_slave_write_addr_bits_addr` …), AXI4 slave node (256 KiB window, single-beat, 128-bit), AXI4 master node (`IdRange(0,64)`), `IntSourceNode(2)`, control `TLRegisterNode`; attached through `SubsystemInjectorKey` (same mechanism as `WithInitZero`), so no `DigitalTop` edit | written, **not compiled** |
| 2 | Attachment chains copied from upstream: slave = `AXI4Buffer := AXI4UserYanker := AXI4IdIndexer(6) := TLToAXI4 := TLWidthWidget(pbus) := TLFragmenter(holdFirstDeny)`; master = rocket-chip `CanHaveSlaveAXI4Port` chain with `AXI4IdIndexer(1)`; interrupts `ibus.fromSync` | written |
| 3 | `stall`/reset: `CoreMiniAxi` has **no stall port**; Coral's own CSR RESET reg (bit0 reset, bit1 clock-gate, por=3) is the stall+reset control. Wrapper adds CTRL.soft_reset (aresetn) and STATUS readback at `0x6004_0000` | design decision, documented in README |
| 4 | `WithCoralNPU`, `CoralNPURocketConfig`, `CoralNPUCVA6Config`, `FireSimCVA6CoralNPUConfig`, `FireSimRocketCoralNPUConfig` | written |
| 5 | Firmware `firmware/coralnpu_fw.S` assembled here with clang 18 (`--target=riscv32 -march=rv32imf`, no C) → 19 words, `mpause = 0x08000073`; `build-fw.sh` rejects compressed encodings | **built and disassembled here** (`coralnpu_fw.dis`) |
| 6 | `tests/coralnpu.c` bare-metal test: reset release → RESET=3 → ITCM load+readback → PC_START → RESET=1 → RESET=0 → poll halted → DTCM check → `coralnpu: PASS` | written, **not run** (no Chipyard/Verilator here) |
| 7 | `export-coralnpu-sv.sh`: bazel emit + unzip `CoreMiniAxi.zip` (split SV + CVFPU/common_cells/ClockGate/RstSync/SRAM resources) → single `coralnpu_core_mini_axi.sv`, packages first | written, **not run** (bazel fetch blocked here) |
| 8 | `tools/check_ports.py`: parses `module CoreMiniAxi(` and checks names/widths of the 100+ ports the blackbox uses, flags untied inputs | written; self-test only against `/dev/null` |
| 9 | Verilator run of the bare-metal test | **NOT DONE** — needs the manager (Chipyard toolchain). Blocking gate for Phase 4 per the plan. |

### CHECKPOINT (end of Phase 2)
- **Works:** firmware assembles cleanly with the mandated ISA; all Chipyard-side sources exist as a reviewable overlay + apply script.
- **Doesn't work / unverified:** nothing has been elaborated or simulated. Expect first-compile fixes.
- **Blocking:** Chipyard toolchain + Verilator (manager instance), Coral SV generation (bazel needs GitHub archive access).

## Phase 3 — Linux-side loader and workload (source work)

| # | Item | Outcome |
|---|---|---|
| 1 | `linux/coralnpu-run.c`: `/dev/mem` mmap of `0x6000_0000` (256 KiB) and `0x6004_0000` (4 KiB); same sequence as the bare-metal test; `CORALNPU PASS` / `CORALNPU FAIL: <why>`; exit code 0/1; `--timeout-ms` | written, **not compiled** (no riscv64-linux toolchain here) |
| 2 | FireMarshal `coralnpu-linux.json`: `base: br-base.json`, `host-init.sh` builds the loader statically with `riscv64-unknown-linux-gnu-gcc` into `overlay/root/`, `command` runs it post-boot so the UART shows PASS without interaction | written, **not built** |
| 3 | Device tree: diplomacy emits a `coralnpu` node (`compatible = "google,coralnpu-v2"`, `reg` = both windows, 2 PLIC interrupts) from `SimpleDevice` + `device.reg` / `device.int`; no manual DTS edit | by construction; verify in the generated `.dts` on the manager |

### CHECKPOINT (end of Phase 3)
- **Works:** loader + workload sources complete.
- **Doesn't work:** unbuilt. Full Linux+loader Verilator flow (Phase 4 parallel task) needs the manager and, for CVA6, VCS.
- **Blocking:** same as Phase 2.

## Phase 1 / 4 / 5 — NOT STARTED (need AWS)

`firesim managerinit`, both bitstream builds, and the F2 runs need a manager
instance. Cost plan proposed to the user; waiting for credentials.

## Phase 2 (continued) — local Chipyard toolchain obtained; wrapper elaborates

The user's reply ("aws login when needed, ask for creds") did not unblock AWS
yet, so the container was used to de-risk the source work instead.

| # | Command | Outcome |
|---|---|---|
| 1 | Miniforge (user-space, `~/miniforge3`) + `git clone --branch 1.14.0 chipyard ~/chipyard` + `./build-setup.sh --use-lean-conda --skip-ctags --skip-clean` | OK after ~25 min; 12 GB; provides sbt, firtool, Verilator, riscv64-unknown-elf and riscv64-unknown-linux-gnu toolchains |
| 2 | `apply-overlay.sh ~/chipyard` | Revealed that `tests/coralnpu.c` and `linux/coralnpu-run.c` were **never written** (a failed `cd` in the authoring shell skipped two heredocs). Recreated and committed (`6393e8d`, `c6a8c35`). |
| 3 | `make CONFIG=CoralNPURocketConfig verilog` (first attempt) | **FAILED**: `env.sh` sourced without conda on PATH → system Java, sbt crashed. My mistake, not a code problem. |
| 4 | same, with `source ~/miniforge3/etc/profile.d/conda.sh` first | **OK, exit 0.** Scala compiled with only two deprecation warnings (old `LazyModule` import; fixed). Diplomacy: NPU interrupts 1,2; memory map `60000000-60040000 ARWX coralnpu`, `60040000-60041000 ARW`; DTS node `coralnpu@60040000 { compatible = "google,coralnpu-v2"; interrupts = <1 2>; reg = <0x60040000 0x1000 0x60000000 0x40000>; reg-names = "control", "mem"; }`; firtool emitted `gen-collateral/CoralNPU.sv` instantiating `CoreMiniAxi` with the expected 100+ `io_*` port names. |
| 5 | `cmake --build tests/build --target coralnpu` | **OK**: `coralnpu.riscv` (36928 B) with the Chipyard rv64 toolchain |
| 6 | `riscv64-unknown-linux-gnu-gcc -static ... coralnpu-run.c` | **OK**: static rv64 Linux ELF; also clean under host `gcc -Wall -Wextra` |
| 7 | Real Coral SV without bazel: `git clone` cvfpu/common_cells/fpu_div_sqrt_mvp at the pinned SHAs (git works where archive downloads are 403), applied the 3 `third_party/cvfpu` patches, resource root mirroring bazel's `external/...` + `hdl/...` layout, sbt project with Chisel 7.0.0-RC1 from Maven, `runMain coralnpu.EmitCore --useAxi ...` | **in progress** (background) |

### CHECKPOINT (Phase 2, second pass)
- **Works:** wrapper compiles and elaborates on a Rocket host; DTS/memory map/interrupts as designed; bare-metal test and Linux loader compile.
- **Doesn't work yet:** nothing simulated; Coral SV not yet generated.
- **Blocking:** Verilator run needs the Coral SV (sbt route running). Everything else still needs the manager instance.

## Phase 2 — gate reached: bare-metal test PASSES in Verilator with the real NPU

| # | Command | Outcome |
|---|---|---|
| 8 | sbt route, attempt 1 (Scala 2.13.12) | FAILED: Chisel 7.0.0-RC1 needs scala-library ≥ 2.13.16 (SIP-51) |
| 9 | attempt 2 (2.13.16) | FAILED: `SpiMaster.scala` needs the excluded rocket-chip file; `ScmInfo` is bazel-generated |
| 10 | attempt 3 (exclude `SpiMaster.scala`, generate `ScmInfo` from `git rev-parse HEAD` like `utils/scm_info.py`) | Scala OK; FAILED at elaboration: `RstSync.sv` resource not found (bazel strips `hdl/verilog` for ClockGate/RstSync) |
| 11 | attempt 4 (add `hdl/verilog` as a second resource root) | **OK**: `CoreMiniAxi.sv` (1.5 MB, 115 modules incl. CVFPU, ClockGate, RstSync, SRAM models inlined by firtool) + `CoreMiniAxi.zip`. 5 Chisel warnings, all in Coral's own `Library.scala` enum casts. Route scripted as `emit-coralnpu-sv-sbt.sh`. |
| 12 | `tools/check_ports.py CoreMiniAxi.sv` | first run reported 91 problems — a parser bug (firtool groups ports, one `input` keyword for several names). Fixed; **95 expected ports, 0 problems, 0 untied inputs**. |
| 13 | `export-coralnpu-sv.sh --from-dir` | flattened bundle; dropped firtool verification-layer bind files; found **module-name collisions** `ram_2x8`, `ram_2x145` with Chipyard's own generated memories → bundle now prefixes `ram_<d>x<w>` as `coralnpu_ram_*`; 0 collisions after |
| 14 | `CORALNPU_SV=<bundle> make -j4 CONFIG=CoralNPURocketConfig run-binary BINARY=tests/build/coralnpu.riscv` | **PASS**. Verilator log (`platforms/chipyard/logs/verilator-CoralNPURocketConfig-coralnpu.log`): `CTRL.STATUS=0x0` after reset release, 19 words loaded, `CSR STATUS=0x1 after 1 polls, CTRL.STATUS=0x1`, `DTCM[0]=0x6688aacc DTCM[1]=0x40700000 DTCM[2]=0xc0de0001`, `coralnpu: PASS`, `$finish`. |

What this proves: TL→AXI4 slave path (128-bit, ID 6, address masking, narrow CSR writes landing in the right byte lanes), ITCM/DTCM/CSR access, Coral's reset/clock-gate sequence, the wrapper control block, FPU inside the NPU, `halted` readback both ways. Not exercised yet: the NPU's AXI **master** path (firmware touched only TCMs), PLIC delivery of `halted`/`fault`, CVA6 host, Linux.

### CHECKPOINT (Phase 2 — complete for the Rocket host)
- **Works:** end-to-end bare-metal NPU test in Verilator with the real `CoreMiniAxi`.
- **Doesn't work / not done:** CVA6 host not simulated (VCS-only); NPU master path untested.
- **Blocking for Phases 1/4/5:** AWS credentials + manager instance.
