# Coral NPU × FlooNoC mesh

A grid/mesh of Coral NPU (`CoreMiniAxi`) tiles connected by a
[FlooNoC](https://github.com/pulp-platform/FlooNoC) network-on-chip with XY
routing. Two configurations are provided:

**`coralnpu_floo_mesh`** — 2×2 Coral tiles plus a host port and a
shared-memory port:

```
      y=1   [coral 0,1]--[R 0,1]-------[R 1,1]--[coral 1,1]
                            |             |  \
                            |             |   `-- mem (East, 0x8000_0000)
      y=0   [coral 0,0]--[R 0,0]-------[R 1,0]--[coral 1,0]
                         /
              host (West)
```

**`coralnpu_snitch_mesh`** — 8 Coral tiles around a central
[Snitch cluster](https://github.com/pulp-platform/snitch_cluster) hub: a
RISC-V manycore (8 compute cores + 1 DMA core) with a large shared TCDM
SRAM (512 KiB in the provided config) that orchestrates the Coral tiles and
stages data for them:

```
  y=2  [coral_w 2]--[R 0,2]---[R 1,2]---[R 2,2]--[coral_e 2]
                                 | coral_n
  y=1  [coral_w 1]--[R 0,1]---[R 1,1]---[R 2,1]--[coral_e 1]
           host (W)-/            | snitch           \-mem (E)
  y=0  [coral_w 0]--[R 0,0]---[R 1,0]---[R 2,0]--[coral_e 0]
                                 | coral_s
```

## Why this works

`CoreMiniAxi` already speaks AXI4 on both sides:

* `io_axi_master` — the core's manager port (32-bit address, 128-bit data,
  6-bit ID) for reaching external memory and other tiles.
* `io_axi_slave` — the core's subordinate port exposing its ITCM, DTCM and
  CSRs, which is how a host loads programs and controls the core.

FlooNoC's `floo_axi_chimney` network interfaces convert exactly this kind of
AXI4 manager/subordinate pair into NoC flits, and its `floo_router` mesh
carries them with XY routing. No protocol conversion beyond struct packing is
required; the FlooGen generator emits the whole network (chimneys, routers,
system address map) from the YAML files in `floogen/`.

The Snitch cluster hub also speaks AXI4, but on two port pairs with
different widths: a 64-bit *narrow* interface for core loads/stores and a
512-bit *wide* interface for its DMA engine, both with 48-bit addresses.
`rtl/snitch_floo_hub.sv` adapts them to the mesh's single 128-bit protocol:
both manager ports are width-converted with `axi_dw_converter`, lifted into
the 32-bit NoC address domain, and muxed onto the hub's NoC manager port;
the NoC subordinate port is width- and ID-converted down onto the cluster's
narrow-in port, exposing the TCDM and cluster peripherals to the whole mesh.

## Directory contents

| Path | Description |
|---|---|
| `floogen/coralnpu_mesh_2x2.yml` | FlooGen configuration of the 2×2 Coral mesh |
| `floogen/coralnpu_snitch_mesh_3x3.yml` | FlooGen configuration of the 3×3 mesh with Snitch hub |
| `generated/` | NoC RTL emitted by FlooGen from those configs (checked in) |
| `rtl/coralnpu_floo_tile.sv` | One tile: `CoreMiniAxi` adapted to the NoC's AXI struct ports |
| `rtl/coralnpu_floo_mesh.sv` | Top level of the 2×2 Coral mesh |
| `rtl/snitch_floo_hub.sv` | Hub tile: Snitch cluster adapted to the mesh protocol |
| `rtl/snitch_floo_hub_pkg.sv` | AXI types/widths of the hub conversion chain |
| `rtl/axi_resize_adapter.sv` | Field-wise AXI addr/ID/user width adapter |
| `rtl/coralnpu_snitch_mesh.sv` | Top level of the 3×3 hub mesh |
| `snitch/coralnpu_hub_cluster.json` | clustergen config: 512 KiB TCDM cluster at `0x2000_0000` |
| `lint/lint.sh` | Verilator lint of both mesh tops (uses port stubs for the generated cores) |
| `lint/CoreMiniAxi_stub.sv` | Port-accurate lint-only stub of the Bazel-generated core |
| `lint/snitch_cluster_wrapper_stub.sv` | Port-accurate lint-only stub of the clustergen output |
| `Bender.yml` | Source/dependency manifest for Bender-based flows |
| `Makefile` | `make noc-rtl` regenerates `generated/` from the YAMLs |

## Memory map

Each Coral tile occupies a 256 KiB window in the 32-bit system address
space; the NoC routes by address (`use_id_table`), and the tile wrapper
masks incoming subordinate addresses down to the core's local offsets
(`+0x0_0000` ITCM 8 KiB, `+0x1_0000` DTCM 32 KiB, `+0x3_0000` CSR 4 KiB).

2×2 Coral mesh:

| System address | Target |
|---|---|
| `0x1000_0000` | coral tile (0,0) |
| `0x1004_0000` | coral tile (0,1) |
| `0x1008_0000` | coral tile (1,0) |
| `0x100C_0000` | coral tile (1,1) |
| `0x8000_0000`–`0x8100_0000` | shared memory (16 MiB), served by whatever sits on `mem_axi_*` |

3×3 Snitch-hub mesh:

| System address | Target |
|---|---|
| `0x1000_0000` | coral_w tiles y=0..2 (3 × 256 KiB) |
| `0x1010_0000` | coral_e tiles y=0..2 (3 × 256 KiB) |
| `0x1020_0000` | coral_n tile |
| `0x1024_0000` | coral_s tile |
| `0x2000_0000`–`0x2010_0000` | Snitch cluster hub: TCDM SRAM (512 KiB), then cluster peripherals and zero-memory per the cluster config |
| `0x8000_0000`–`0x8100_0000` | shared memory (16 MiB) |

Any tile can reach any other tile's ITCM/DTCM/CSR window, the hub's TCDM,
and the shared memory through its own manager port. In the hub mesh the
intended dataflow is Snitch-orchestrated: the cluster DMA stages
activations/weights from shared memory into its big TCDM, scatters work
into the Coral tiles' DTCMs (or the tiles pull from the TCDM), and Snitch
cores handle control, synchronization, and anything the NPUs don't
accelerate. The host port can reach everything; typical bring-up is: write
each tile's ITCM/DTCM through its window, set per-tile `boot_addr_i`, then
release the tile via its CSRs (same sequence the single-core cocotb tests
use, just offset by the tile window base).

## Regenerating / scaling the mesh

The generator is FlooGen from the FlooNoC repository (pinned:
FlooNoC `8a67b860490b3b6b82289c281f5324b287572c8a`, floogen 0.8.4):

```bash
git clone https://github.com/pulp-platform/FlooNoC.git
pip install ./FlooNoC       # provides the `floogen` CLI
make noc-rtl                # regenerates generated/ from both YAMLs
```

To scale the plain mesh to, say, a 4×4 grid, edit
`floogen/coralnpu_mesh_2x2.yml`:

1. `endpoints.coral.array` and `routers.router.array` → `[4, 4]`
2. the `coral`→`router` connection `src_range`/`dst_range` → `[0, 3]` each
3. keep 0x4_0000 per-tile window size; 16 tiles fit in
   `0x1000_0000`–`0x1040_0000`

then rerun `make noc-rtl`. `rtl/coralnpu_floo_mesh.sv` needs no edits: it
reads `NumCoralX`/`NumCoralY` from the generated package. The enums and the
system address map in the generated package grow automatically. The hub
mesh scales the same way (grow the `coral_w`/`coral_e` columns and router
array, keep the hub at the center router), though
`rtl/coralnpu_snitch_mesh.sv` port slicing must be updated to match.

## Building the core RTL

`CoreMiniAxi.sv` is generated from Chisel by Bazel and is not checked in
here:

```bash
bazel build //hdl/chisel/src/coralnpu:core_mini_axi_cc_library
```

`snitch_cluster_wrapper.sv` is generated by the snitch_cluster repository's
clustergen flow (pinned: `ccde489fb287543e548e844fc6cb4943eee4797a`) from
the config in `snitch/coralnpu_hub_cluster.json`:

```bash
git clone https://github.com/pulp-platform/snitch_cluster.git
# from the snitch_cluster checkout, generate with the hub config, e.g.:
make -C target/snitch_cluster CFG_OVERRIDE=<path>/snitch/coralnpu_hub_cluster.json rtl
```

If the cluster config changes any AXI interface width (address, data, ID,
or user), update the matching localparams in `rtl/snitch_floo_hub_pkg.sv`.

Add the generated `CoreMiniAxi.sv` (plus SRAM/RVV support files) and the
snitch_cluster sources to your filelist alongside the sources listed in
`Bender.yml`, plus the FlooNoC, `axi` and `common_cells` sources (revisions
in `lint/lint.sh`, taken from FlooNoC's `Bender.lock`).

## Verification status

* Both mesh tops (generated NoCs + tile/hub wrappers) elaborate cleanly
  under `verilator --lint-only` with zero errors and no warnings in the
  integration RTL — run `lint/lint.sh`. The Coral core and the Snitch
  cluster are stubbed for lint so the check runs without their generators.
* No simulation testbench yet. The natural next step is a cocotb bench that
  reuses `coralnpu_test_utils` AXI drivers on the host port: load a small
  binary into tile (0,0)'s ITCM via `0x1000_0000`, have it write a result to
  a neighbor tile's DTCM or shared memory, and check it. For the hub mesh,
  the follow-on test is a Snitch program that DMAs a buffer from shared
  memory into TCDM and scatters it into a Coral tile's DTCM.

## Design notes & limitations

* **Address masking, not translation.** The tile wrapper masks subordinate
  addresses with `LocalAddrMask = 0x0003_FFFF`. Accesses inside a window but
  outside ITCM/DTCM/CSR get error responses from the core's own decoder, as
  on a single core.
* **IDs and user signals.** Both NoC protocols use 6-bit IDs matching the
  core, so IDs pass through unmodified. Coral's AXI has no `user` or `atop`
  signals; they are tied to zero entering the NoC.
* **Hub width conversion.** The Snitch wide (512-bit) and narrow (64-bit)
  ports are serialized/packed onto the 128-bit NoC, so peak hub DMA
  bandwidth is NoC-limited — matched to what the 128-bit Coral tiles can
  absorb anyway. If the hub needs more inbound bandwidth later, FlooNoC's
  narrow-wide (`nw`) network type can carry a separate wide physical
  channel.
* **Hub addressing.** Cluster software must use 32-bit system addresses;
  bits above 31 are truncated at the NoC boundary (the cluster's own
  48-bit address space is only used internally). AXI atomics from Snitch
  cores must stay within the cluster TCDM — the NoC and Coral tiles do not
  support `atop`.
* **Single clock domain.** Everything runs on `clk_i`. FlooNoC supports
  per-region CDC (`floo_cdc`) if tiles should run on their own clocks later.
* **`floo_vc_arbiter` pin patch in lint.** FlooNoC master's virtual-channel
  arbiter names a `cc_credit_counter` pin that the common_cells revision in
  FlooNoC's own `Bender.lock` doesn't have. This mesh uses no virtual
  channels, so the module is unused; `lint/lint.sh` patches the pin name
  locally so the orphan module still parses. Not needed in flows that only
  compile the used hierarchy.
