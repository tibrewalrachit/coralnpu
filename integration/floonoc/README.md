# Coral NPU × FlooNoC mesh

A grid/mesh of Coral NPU (`CoreMiniAxi`) tiles connected by a
[FlooNoC](https://github.com/pulp-platform/FlooNoC) network-on-chip with XY
routing. The default configuration is a 2×2 mesh plus a host port and a
shared-memory port; it scales to larger grids by editing one YAML file and
regenerating.

```
      y=1   [coral 0,1]--[R 0,1]-------[R 1,1]--[coral 1,1]
                            |             |  \
                            |             |   `-- mem (East, 0x8000_0000)
      y=0   [coral 0,0]--[R 0,0]-------[R 1,0]--[coral 1,0]
                         /
              host (West)
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
system address map) from `floogen/coralnpu_mesh_2x2.yml`.

## Directory contents

| Path | Description |
|---|---|
| `floogen/coralnpu_mesh_2x2.yml` | FlooGen configuration (mesh size, protocols, address map) |
| `generated/` | NoC RTL emitted by FlooGen from that config (checked in) |
| `rtl/coralnpu_floo_tile.sv` | One tile: `CoreMiniAxi` adapted to the NoC's AXI struct ports |
| `rtl/coralnpu_floo_mesh.sv` | Top level: N×M tiles + generated NoC, host and memory ports |
| `lint/lint.sh` | Verilator lint of the full mesh (uses a port stub for `CoreMiniAxi`) |
| `lint/CoreMiniAxi_stub.sv` | Port-accurate lint-only stub of the Bazel-generated core |
| `Bender.yml` | Source/dependency manifest for Bender-based flows |
| `Makefile` | `make noc-rtl` regenerates `generated/` from the YAML |

## Memory map

Each tile occupies a 256 KiB window in the 32-bit system address space; the
NoC routes by address (`use_id_table`), and the tile wrapper masks incoming
subordinate addresses down to the core's local offsets.

| System address | Target |
|---|---|
| `0x1000_0000` | coral tile (0,0) — `+0x0_0000` ITCM (8 KiB), `+0x1_0000` DTCM (32 KiB), `+0x3_0000` CSR (4 KiB) |
| `0x1004_0000` | coral tile (0,1), same layout |
| `0x1008_0000` | coral tile (1,0), same layout |
| `0x100C_0000` | coral tile (1,1), same layout |
| `0x8000_0000`–`0x8100_0000` | shared memory (16 MiB), served by whatever memory sits on `mem_axi_*` |

Any tile can reach any other tile's ITCM/DTCM/CSR window and the shared
memory through its own manager port, so cores can DMA activations/weights to
each other or synchronize through shared memory. The host port can reach
everything; typical bring-up is: write each tile's ITCM/DTCM through its
window, set per-tile `boot_addr_i`, then release the tile via its CSRs
(same sequence the single-core cocotb tests use, just offset by the tile
window base).

## Regenerating / scaling the mesh

The generator is FlooGen from the FlooNoC repository (pinned:
FlooNoC `8a67b860490b3b6b82289c281f5324b287572c8a`, floogen 0.8.4):

```bash
git clone https://github.com/pulp-platform/FlooNoC.git
pip install ./FlooNoC       # provides the `floogen` CLI
make noc-rtl                # regenerates generated/ from the YAML
```

To scale to, say, a 4×4 grid, edit `floogen/coralnpu_mesh_2x2.yml`:

1. `endpoints.coral.array` and `routers.router.array` → `[4, 4]`
2. the `coral`→`router` connection `src_range`/`dst_range` → `[0, 3]` each
3. keep 0x4_0000 per-tile window size; 16 tiles fit in
   `0x1000_0000`–`0x1040_0000`

then rerun `make noc-rtl`. `rtl/coralnpu_floo_mesh.sv` needs no edits: it
reads `NumCoralX`/`NumCoralY` from the generated package. The enums and the
system address map in `generated/floo_coralnpu_mesh_noc_pkg.sv` grow
automatically.

## Building the core RTL

`CoreMiniAxi.sv` is generated from Chisel by Bazel and is not checked in
here:

```bash
bazel build //hdl/chisel/src/coralnpu:core_mini_axi_cc_library
```

Add the resulting `CoreMiniAxi.sv` (and the SRAM/RVV support files from the
same bundle) to your filelist alongside the sources listed in `Bender.yml`,
plus the FlooNoC, `axi` and `common_cells` sources (revisions in
`lint/lint.sh`, taken from FlooNoC's `Bender.lock`).

## Verification status

* The complete mesh (generated NoC + tile wrappers + top) elaborates cleanly
  under `verilator --lint-only` with zero errors and no warnings in the
  integration RTL — run `lint/lint.sh`. The core itself is stubbed for lint
  so the check runs without a Bazel build.
* No simulation testbench yet. The natural next step is a cocotb bench that
  reuses `coralnpu_test_utils` AXI drivers on the host port: load a small
  binary into tile (0,0)'s ITCM via `0x1000_0000`, have it write a result to
  a neighbor tile's DTCM or shared memory, and check it.

## Design notes & limitations

* **Address masking, not translation.** The tile wrapper masks subordinate
  addresses with `LocalAddrMask = 0x0003_FFFF`. Accesses inside a window but
  outside ITCM/DTCM/CSR get error responses from the core's own decoder, as
  on a single core.
* **IDs and user signals.** Both NoC protocols use 6-bit IDs matching the
  core, so IDs pass through unmodified. Coral's AXI has no `user` or `atop`
  signals; they are tied to zero entering the NoC.
* **Single clock domain.** Everything runs on `clk_i`. FlooNoC supports
  per-region CDC (`floo_cdc`) if tiles should run on their own clocks later.
* **`floo_vc_arbiter` pin patch in lint.** FlooNoC master's virtual-channel
  arbiter names a `cc_credit_counter` pin that the common_cells revision in
  FlooNoC's own `Bender.lock` doesn't have. This mesh uses no virtual
  channels, so the module is unused; `lint/lint.sh` patches the pin name
  locally so the orphan module still parses. Not needed in flows that only
  compile the used hierarchy.
