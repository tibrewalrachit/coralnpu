# CVA6 + Coral NPU on Chipyard / FireSim (AWS F2)

Everything needed to attach Coral NPU (`CoreMiniAxi`, scalar + FPU, AXI) to a
Chipyard SoC as a **SystemVerilog blackbox**, run a bare-metal smoke test in
Verilator, boot Linux on a FireSim-simulated **CVA6** on **AWS F2**, and have a
user-space loader print `CORALNPU PASS` on the UART.

Status of this directory: written against **FireSim 1.21.0 / Chipyard 1.14.0 /
rocket-chip `55bcad0`** by reading their sources. It has **not** been compiled
or simulated yet (the authoring machine had no Chipyard toolchain, no Vivado
and no AWS access). See `../../BRINGUP_LOG.md` for what was and was not run.

## Layout

| Path | What |
|---|---|
| `overlay/chipyard/generators/chipyard/src/main/scala/example/CoralNPU.scala` | Blackbox + diplomatic wrapper + `WithCoralNPU` config fragment (SubsystemInjector, no `DigitalTop` edit) |
| `overlay/chipyard/generators/chipyard/src/main/scala/config/CoralNPUConfigs.scala` | `CoralNPURocketConfig` (Verilator), `CoralNPUCVA6Config` |
| `overlay/chipyard/generators/firechip/chip/src/main/scala/CoralNPUTargetConfigs.scala` | `FireSimCVA6CoralNPUConfig`, `FireSimRocketCoralNPUConfig` |
| `overlay/chipyard/tests/coralnpu.c` | Bare-metal test (host core loads ITCM, runs NPU, checks DTCM) |
| `firmware/` | RV32IMF (no C) NPU firmware, `build-fw.sh` (clang), generated `.bin`/`.h` |
| `linux/coralnpu-run.c` | Linux `/dev/mem` loader, same sequence, prints `CORALNPU PASS/FAIL` |
| `firemarshal/coralnpu-linux.json` + `coralnpu-linux/` | FireMarshal workload (br-base + loader as post-boot command) |
| `firesim/*.yaml` | Build recipes / hwdb / builds_to_run for the two F2 bitstreams |
| `export-coralnpu-sv.sh` | Generates and flattens the NPU SV bundle with Coral's bazel flow |
| `apply-overlay.sh` | Copies the overlay into a Chipyard checkout, registers the test |
| `tools/check_ports.py` | Verifies the generated SV port list against the blackbox |

## Memory map (host view)

| Range | Size | What | NPU-local |
|---|---|---|---|
| `0x6000_0000 – 0x6000_1FFF` | 8 KiB | ITCM | `0x0000_0000` |
| `0x6001_0000 – 0x6001_7FFF` | 32 KiB | DTCM | `0x0001_0000` |
| `0x6003_0000 – 0x6003_0FFF` | 4 KiB | Coral CSR block | `0x0003_0000` |
| `0x6004_0000 – 0x6004_0FFF` | 4 KiB | Wrapper control block (TL register node) | n/a |

The wrapper masks the AXI address with `0x3FFFF` before handing it to the NPU,
so the NPU sees its native map. The NPU's AXI master issues 32-bit addresses
that pass through unchanged onto the front bus (DRAM at `0x8000_0000` is
reachable).

Coral CSR block (from `hdl/chisel/src/coralnpu/CoreAxiCSR.scala`):

| Offset | Register | Bits |
|---|---|---|
| `+0x0` | RESET | `[0]` core reset (active high) `[1]` clock gate. **Power-on value 3** |
| `+0x4` | PC_START | 32-bit start PC (NPU-local) |
| `+0x8` | STATUS | `[0]` halted `[1]` fault |

Wrapper control block:

| Offset | Register | Bits |
|---|---|---|
| `+0x0` | CTRL | `[0]` soft_reset: drives NPU `aresetn` low. **Power-on value 1** `[1]` irq into the NPU |
| `+0x4` | STATUS (RO) | `[0]` halted `[1]` fault `[2]` wfi |

Interrupts: `halted` and `fault` are PLIC sources (device `coralnpu`,
`compatible = "google,coralnpu-v2"`, two `interrupts` entries). The DTS node
with `reg` for both windows is emitted automatically by diplomacy, so Linux
knows the range and no other driver claims it.

Bus widths (explicit, must match the generated SV): AXI ID 6, ADDR 32, DATA 128
on both NPU ports. `AXI4IdIndexer(6)` on the slave side, `AXI4IdIndexer(1)` +
`AXI4Fragmenter` + `AXI4UserYanker(Some(8))` on the master side, all same clock.

### The load / run sequence (both the bare-metal test and the Linux loader)

1. `CTRL.soft_reset = 0` (release `aresetn`; Coral's `RstSync` synchronises it)
2. `RESET = 3` (core in reset, clock gated; this is the reset value)
3. write firmware words to ITCM, read back, zero the DTCM result words
4. `PC_START = 0`
5. `RESET = 1` (ungate clock, keep reset) then `RESET = 0` (run)
6. poll `STATUS[0]` = halted, check `STATUS[1]` = fault, read DTCM

Expected DTCM: `[0]=0x6688AACC` (int add), `[1]=0x40700000` (1.5f+2.25f),
`[2]=0xC0DE0001` (done marker). The firmware ends with `mpause`
(`.word 0x08000073`) which raises `halted`.

## Reproduce from a clean manager instance

```bash
# 0. Manager instance: FPGA Developer AMI, F2-capable region, FireSim 1.21.0
git clone https://github.com/firesim/firesim && cd firesim && git checkout 1.21.0
./build-setup.sh                       # installs conda env + Chipyard 1.14.0
source sourceme-manager.sh
export FS_DIR=$PWD CY_DIR=$PWD/target-design/chipyard

# 1. Coral NPU SV (needs bazel 7.4.1 via bazelisk, network access to GitHub archives)
git clone https://github.com/google-coral/coralnpu ~/coralnpu   # or this fork
cd ~/coralnpu && ./platforms/chipyard/export-coralnpu-sv.sh      # -> build/coralnpu-sv/coralnpu_core_mini_axi.sv
export CORALNPU_SV=$HOME/coralnpu/build/coralnpu-sv/coralnpu_core_mini_axi.sv

# 2. Chipyard overlay + bare-metal test in Verilator (Rocket host; CVA6 is VCS-only)
~/coralnpu/platforms/chipyard/apply-overlay.sh $CY_DIR
cd $CY_DIR/tests && cmake -S . -B build && cmake --build build --target coralnpu
cd $CY_DIR/sims/verilator && make CONFIG=CoralNPURocketConfig \
  run-binary BINARY=$CY_DIR/tests/build/coralnpu.riscv 2>&1 | tee coralnpu-verilator.log
grep "coralnpu: PASS" coralnpu-verilator.log

# 3. FireMarshal workload (Linux + loader)
cp -r ~/coralnpu/platforms/chipyard/firemarshal/coralnpu-linux* $CY_DIR/software/firemarshal/workloads/
cd $CY_DIR/software/firemarshal
CORALNPU_DIR=$HOME/coralnpu ./marshal -v build workloads/coralnpu-linux.json
./marshal -v install workloads/coralnpu-linux.json     # -> $FS_DIR/deploy/workloads/coralnpu-linux.json

# 4. FireSim bitstreams (z1d.2xlarge each, 2-6 h)
cd $FS_DIR/deploy
firesim managerinit --platform f2
cat ~/coralnpu/platforms/chipyard/firesim/config_build_recipes_coralnpu.yaml >> config_build_recipes.yaml
# edit config_build.yaml builds_to_run per firesim/config_build_coralnpu.yaml
firesim buildbitstream                                  # prints the hwdb entry (agfi) per build

# 5. Run on F2 (f2.6xlarge)
#   config_hwdb.yaml: add the printed entries (see firesim/config_hwdb_coralnpu.yaml)
#   config_runtime.yaml: default_hw_config: firesim_cva6_singlecore_no_nic_baseline, workload_name: br-base-uniform.json
firesim launchrunfarm && firesim infrasetup && firesim runworkload      # baseline: Linux boots, uartlog captured
#   then default_hw_config: firesim_cva6_singlecore_no_nic_coralnpu, workload_name: coralnpu-linux.json
firesim infrasetup && firesim runworkload               # expect "CORALNPU PASS" in deploy/results-workload/*/uartlog
firesim terminaterunfarm
```

## Config names

| Purpose | Name |
|---|---|
| Baseline CVA6 (upstream) | `chipyard.CVA6Config`, FireSim `FireSimCVA6Config` |
| CVA6 + NPU | `chipyard.CoralNPUCVA6Config`, FireSim `FireSimCVA6CoralNPUConfig` |
| Rocket + NPU (Verilator) | `chipyard.CoralNPURocketConfig`, FireSim `FireSimRocketCoralNPUConfig` |
| Fragment | `chipyard.example.WithCoralNPU`, `WithCoralNPUAt(base, ctrlBase)` |
| Build recipes | `firesim_cva6_singlecore_no_nic_baseline`, `firesim_cva6_singlecore_no_nic_coralnpu` |

AGFI IDs: none yet (no builds have run). Fill `firesim/config_hwdb_coralnpu.yaml`
from the `firesim buildbitstream` output.

## Known caveats

- **Unverified code.** Elaboration, Verilator, VCS, Vivado and F2 runs are all
  still to do. First things to expect: Scala compile nits in `CoralNPU.scala`,
  `check_ports.py` disagreements if Coral's port naming differs from the
  Chisel bundle flattening assumed here, and SV file ordering inside the
  flattened bundle.
- Chipyard documents CVA6 as **VCS-only** for software simulation. The
  bare-metal test therefore targets `CoralNPURocketConfig`; Linux-on-CVA6 in
  software sim needs a VCS licence on the manager.
- `boot_addr`, `te`, and the debug-module port are tied off; `io_debug_*`
  trace outputs are left unconnected.
- Coral's AXI slave is single-outstanding per direction; the wrapper advertises
  single-beat transfers only, which the `TLFragmenter`/`TLWidthWidget` chain
  guarantees. Bursts from the host are never generated.

## Next steps

- **FASED LPDDR4 timing.** The F2 recipe uses `FRFCFS16GBQuadRankLLC4MB`
  (DDR3 timings). To model an LPDDR4-class mobile memory, add a FASED
  `WithDDR...`-style config with LPDDR4 `tRCD/tRP/tRAS/tRFC` and bank-group
  parameters in `generators/firechip/.../FASED` and regenerate the runtime
  config with the FASED config generator; no RTL change.
- **RVV variant.** Regenerate with `//hdl/chisel/src/coralnpu:rvv_core_mini_axi_cc_library_emit_verilog`
  (module `RvvCoreMiniAxi`), pass `moduleName = "RvvCoreMiniAxi"` in
  `CoralNPUParams`, re-run `check_ports.py` (the RVV build adds common_cells
  include paths, so the flattening script must inline `.svh` files), and
  extend the firmware with a `vsetvli`/`vadd.vv` check (`-march=rv32imf_zve32x`).
- **Cheshire-based design.** Cheshire is an AXI-native SoC (CVA6 + AXI xbar +
  reg-bus). The wrapper's diplomatic glue goes away: the NPU slave hangs off
  the AXI crossbar as a plain subordinate with a 256 KiB window (an
  `axi_dw_converter` 64→128 in front), the master joins the crossbar as a
  manager with an `axi_id_remap`, and the two-register control block becomes
  a small reg-bus peripheral. The interrupts route to Cheshire's PLIC. The
  firmware, sequence, and Linux loader stay identical; only the base address
  in `coralnpu-run --base` changes. FireSim support for Cheshire would need a
  new target project, so that move is better done with a plain Vivado F2
  shell flow than through FireSim.
