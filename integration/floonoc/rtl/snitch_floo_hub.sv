// Copyright 2025 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// Central hub tile: a Snitch cluster (RISC-V manycore with a large shared
// TCDM SRAM, pulp-platform/snitch_cluster) adapted to the Coral NPU
// FlooNoC mesh protocol (32-bit address / 128-bit data / 6-bit ID AXI4).
//
// Manager side (cluster -> NoC): the cluster's 64-bit narrow port (core
// loads/stores) and 512-bit wide port (cluster DMA) are width-converted to
// 128 bits, lifted into the NoC's 32-bit address domain, and muxed onto the
// single NoC manager port. This lets Snitch cores and the cluster DMA reach
// every Coral tile's ITCM/DTCM/CSR window and the shared memory.
//
// Subordinate side (NoC -> cluster): the NoC subordinate port is lifted to
// the cluster's 48-bit address domain, width-converted to 64 bits, and
// ID-width-converted down to the cluster's narrow_in port, exposing the
// TCDM and cluster peripherals at HubBaseAddr. The 512-bit wide_in port is
// unused (inbound bulk traffic is limited by the 128-bit NoC anyway).
//
// Caveats:
//  - Cluster software must address the NoC through 32-bit addresses; upper
//    narrow/wide address bits are truncated at the NoC boundary.
//  - AXI atomics (aw.atop) from the cluster must not target Coral tiles or
//    the NoC (Coral's AXI has no atomics support); the cluster's own TCDM
//    atomics are unaffected.

module snitch_floo_hub
  import snitch_floo_hub_pkg::*;
#(
  // System base address of the cluster (TCDM + peripherals live here).
  parameter logic [SnAddrWidth-1:0] HubBaseAddr = 48'h0000_2000_0000,
  parameter int unsigned NrCores = 9,
  // NoC-facing AXI struct types (FlooGen package of the enclosing mesh).
  parameter type axi_in_req_t  = floo_coralnpu_snitch_mesh_noc_pkg::axi_in_req_t,
  parameter type axi_in_rsp_t  = floo_coralnpu_snitch_mesh_noc_pkg::axi_in_rsp_t,
  parameter type axi_out_req_t = floo_coralnpu_snitch_mesh_noc_pkg::axi_out_req_t,
  parameter type axi_out_rsp_t = floo_coralnpu_snitch_mesh_noc_pkg::axi_out_rsp_t
) (
  input  logic               clk_i,
  input  logic               rst_ni,
  // Cluster sideband
  input  logic [NrCores-1:0] debug_req_i,
  input  logic [NrCores-1:0] meip_i,
  input  logic [NrCores-1:0] mtip_i,
  input  logic [NrCores-1:0] msip_i,
  input  logic [31:0]        hart_base_id_i,
  // AXI manager port into the NoC (cluster cores + DMA -> network)
  output axi_in_req_t        axi_mgr_req_o,
  input  axi_in_rsp_t        axi_mgr_rsp_i,
  // AXI subordinate port from the NoC (network -> TCDM / peripherals)
  input  axi_out_req_t       axi_sbr_req_i,
  output axi_out_rsp_t       axi_sbr_rsp_o
);

  // -------------------------------------------------------------------
  // Snitch cluster
  // -------------------------------------------------------------------
  sn_narrow_in_req_t  narrow_in_req;
  sn_narrow_in_rsp_t  narrow_in_rsp;
  sn_narrow_out_req_t narrow_out_req;
  sn_narrow_out_rsp_t narrow_out_rsp;
  sn_wide_out_req_t   wide_out_req;
  sn_wide_out_rsp_t   wide_out_rsp;

  snitch_cluster_wrapper u_cluster (
    .clk_i                 (clk_i),
    .rst_ni                (rst_ni),
    .debug_req_i           (debug_req_i),
    .meip_i                (meip_i),
    .mtip_i                (mtip_i),
    .msip_i                (msip_i),
    .mxip_i                ('0),
    .hart_base_id_i        (hart_base_id_i),
    .cluster_base_addr_i   (HubBaseAddr),
    .cluster_base_offset_i ('0),
    .clk_d2_bypass_i       (1'b0),
    .sram_cfg_tcdm_i       ('0),
    .sram_cfg_icache_tag_i ('0),
    .sram_cfg_icache_data_i('0),
    .narrow_in_req_i       (narrow_in_req),
    .narrow_in_resp_o      (narrow_in_rsp),
    .narrow_out_req_o      (narrow_out_req),
    .narrow_out_resp_i     (narrow_out_rsp),
    .wide_out_req_o        (wide_out_req),
    .wide_out_resp_i       (wide_out_rsp),
    .wide_in_req_i         ('0),
    .wide_in_resp_o        (/* unused */),
    // Xif coprocessor interface unused
    .x_issue_req_o         (/* unused */),
    .x_issue_resp_i        ('0),
    .x_issue_valid_o       (/* unused */),
    .x_issue_ready_i       ('0),
    .x_register_o          (/* unused */),
    .x_register_valid_o    (/* unused */),
    .x_register_ready_i    ('0),
    .x_commit_o            (/* unused */),
    .x_commit_valid_o      (/* unused */),
    .x_result_i            ('0),
    .x_result_valid_i      ('0),
    .x_result_ready_o      (/* unused */),
    // External TCDM / accelerator ports unused
    .narrow_ext_req_o      (/* unused */),
    .narrow_ext_resp_i     ('0),
    .tcdm_ext_req_i        ('0),
    .tcdm_ext_resp_o       (/* unused */),
    .dca_req_i             ('0),
    .dca_rsp_o             (/* unused */)
  );

  // -------------------------------------------------------------------
  // Manager path: narrow (64b) and wide (512b) -> 128b -> mux -> NoC
  // -------------------------------------------------------------------
  n128_req_t n128_req;
  n128_rsp_t n128_rsp;
  w128_req_t w128_req;
  w128_rsp_t w128_rsp;
  hub_req_t [1:0] hub_reqs;
  hub_rsp_t [1:0] hub_rsps;
  noc_req_t noc_mgr_req;
  noc_rsp_t noc_mgr_rsp;

  axi_dw_converter #(
    .AxiMaxReads         (4),
    .AxiSlvPortDataWidth (SnNarrowDataWidth),
    .AxiMstPortDataWidth (NocDataWidth),
    .AxiAddrWidth        (SnAddrWidth),
    .AxiIdWidth          (SnNarrowIdWidthOut),
    .aw_chan_t           (n128_aw_chan_t),
    .mst_w_chan_t        (n128_w_chan_t),
    .slv_w_chan_t        (sn_narrow_out_w_chan_t),
    .b_chan_t            (n128_b_chan_t),
    .ar_chan_t           (n128_ar_chan_t),
    .mst_r_chan_t        (n128_r_chan_t),
    .slv_r_chan_t        (sn_narrow_out_r_chan_t),
    .axi_mst_req_t       (n128_req_t),
    .axi_mst_resp_t      (n128_rsp_t),
    .axi_slv_req_t       (sn_narrow_out_req_t),
    .axi_slv_resp_t      (sn_narrow_out_rsp_t)
  ) u_narrow_dw (
    .clk_i      (clk_i),
    .rst_ni     (rst_ni),
    .slv_req_i  (narrow_out_req),
    .slv_resp_o (narrow_out_rsp),
    .mst_req_o  (n128_req),
    .mst_resp_i (n128_rsp)
  );

  axi_dw_converter #(
    .AxiMaxReads         (4),
    .AxiSlvPortDataWidth (SnWideDataWidth),
    .AxiMstPortDataWidth (NocDataWidth),
    .AxiAddrWidth        (SnAddrWidth),
    .AxiIdWidth          (SnWideIdWidthOut),
    .aw_chan_t           (w128_aw_chan_t),
    .mst_w_chan_t        (w128_w_chan_t),
    .slv_w_chan_t        (sn_wide_out_w_chan_t),
    .b_chan_t            (w128_b_chan_t),
    .ar_chan_t           (w128_ar_chan_t),
    .mst_r_chan_t        (w128_r_chan_t),
    .slv_r_chan_t        (sn_wide_out_r_chan_t),
    .axi_mst_req_t       (w128_req_t),
    .axi_mst_resp_t      (w128_rsp_t),
    .axi_slv_req_t       (sn_wide_out_req_t),
    .axi_slv_resp_t      (sn_wide_out_rsp_t)
  ) u_wide_dw (
    .clk_i      (clk_i),
    .rst_ni     (rst_ni),
    .slv_req_i  (wide_out_req),
    .slv_resp_o (wide_out_rsp),
    .mst_req_o  (w128_req),
    .mst_resp_i (w128_rsp)
  );

  // Lift both 128-bit streams into the NoC address/ID/user domain.
  axi_resize_adapter #(
    .slv_req_t (n128_req_t),
    .slv_rsp_t (n128_rsp_t),
    .mst_req_t (hub_req_t),
    .mst_rsp_t (hub_rsp_t)
  ) u_narrow_resize (
    .slv_req_i (n128_req),
    .slv_rsp_o (n128_rsp),
    .mst_req_o (hub_reqs[0]),
    .mst_rsp_i (hub_rsps[0])
  );

  axi_resize_adapter #(
    .slv_req_t (w128_req_t),
    .slv_rsp_t (w128_rsp_t),
    .mst_req_t (hub_req_t),
    .mst_rsp_t (hub_rsp_t)
  ) u_wide_resize (
    .slv_req_i (w128_req),
    .slv_rsp_o (w128_rsp),
    .mst_req_o (hub_reqs[1]),
    .mst_rsp_i (hub_rsps[1])
  );

  axi_mux #(
    .SlvAxiIDWidth (HubMuxIdWidth),
    .slv_aw_chan_t (hub_aw_chan_t),
    .mst_aw_chan_t (noc_aw_chan_t),
    .w_chan_t      (noc_w_chan_t),
    .slv_b_chan_t  (hub_b_chan_t),
    .mst_b_chan_t  (noc_b_chan_t),
    .slv_ar_chan_t (hub_ar_chan_t),
    .mst_ar_chan_t (noc_ar_chan_t),
    .slv_r_chan_t  (hub_r_chan_t),
    .mst_r_chan_t  (noc_r_chan_t),
    .slv_req_t     (hub_req_t),
    .slv_resp_t    (hub_rsp_t),
    .mst_req_t     (noc_req_t),
    .mst_resp_t    (noc_rsp_t),
    .NoSlvPorts    (2)
  ) u_mgr_mux (
    .clk_i       (clk_i),
    .rst_ni      (rst_ni),
    .slv_reqs_i  (hub_reqs),
    .slv_resps_o (hub_rsps),
    .mst_req_o   (noc_mgr_req),
    .mst_resp_i  (noc_mgr_rsp)
  );

  assign axi_mgr_req_o = noc_mgr_req;
  assign noc_mgr_rsp   = axi_mgr_rsp_i;

  // -------------------------------------------------------------------
  // Subordinate path: NoC -> 48b address domain -> 64b -> narrow_in
  // -------------------------------------------------------------------
  s128_req_t s128_req;
  s128_rsp_t s128_rsp;
  s64_req_t  s64_req;
  s64_rsp_t  s64_rsp;

  axi_resize_adapter #(
    .slv_req_t (axi_out_req_t),
    .slv_rsp_t (axi_out_rsp_t),
    .mst_req_t (s128_req_t),
    .mst_rsp_t (s128_rsp_t)
  ) u_sbr_resize (
    .slv_req_i (axi_sbr_req_i),
    .slv_rsp_o (axi_sbr_rsp_o),
    .mst_req_o (s128_req),
    .mst_rsp_i (s128_rsp)
  );

  axi_dw_converter #(
    .AxiMaxReads         (4),
    .AxiSlvPortDataWidth (NocDataWidth),
    .AxiMstPortDataWidth (SnNarrowDataWidth),
    .AxiAddrWidth        (SnAddrWidth),
    .AxiIdWidth          (NocIdWidth),
    .aw_chan_t           (s64_aw_chan_t),
    .mst_w_chan_t        (s64_w_chan_t),
    .slv_w_chan_t        (s128_w_chan_t),
    .b_chan_t            (s64_b_chan_t),
    .ar_chan_t           (s64_ar_chan_t),
    .mst_r_chan_t        (s64_r_chan_t),
    .slv_r_chan_t        (s128_r_chan_t),
    .axi_mst_req_t       (s64_req_t),
    .axi_mst_resp_t      (s64_rsp_t),
    .axi_slv_req_t       (s128_req_t),
    .axi_slv_resp_t      (s128_rsp_t)
  ) u_sbr_dw (
    .clk_i      (clk_i),
    .rst_ni     (rst_ni),
    .slv_req_i  (s128_req),
    .slv_resp_o (s128_rsp),
    .mst_req_o  (s64_req),
    .mst_resp_i (s64_rsp)
  );

  axi_iw_converter #(
    .AxiSlvPortIdWidth      (NocIdWidth),
    .AxiMstPortIdWidth      (SnNarrowIdWidthIn),
    .AxiSlvPortMaxUniqIds   (4),
    .AxiSlvPortMaxTxnsPerId (4),
    .AxiSlvPortMaxTxns      (8),
    .AxiMstPortMaxUniqIds   (4),
    .AxiMstPortMaxTxnsPerId (4),
    .AxiAddrWidth           (SnAddrWidth),
    .AxiDataWidth           (SnNarrowDataWidth),
    .AxiUserWidth           (SnNarrowUserWidth),
    .slv_req_t              (s64_req_t),
    .slv_resp_t             (s64_rsp_t),
    .mst_req_t              (sn_narrow_in_req_t),
    .mst_resp_t             (sn_narrow_in_rsp_t)
  ) u_sbr_iw (
    .clk_i      (clk_i),
    .rst_ni     (rst_ni),
    .slv_req_i  (s64_req),
    .slv_resp_o (s64_rsp),
    .mst_req_o  (narrow_in_req),
    .mst_resp_i (narrow_in_rsp)
  );

endmodule
