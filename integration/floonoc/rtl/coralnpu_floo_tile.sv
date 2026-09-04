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

// One Coral NPU mesh tile: a CoreMiniAxi core adapted to the PULP AXI4
// struct interfaces used by the FlooNoC-generated network.
//
// The core's AXI manager port (`io_axi_master`) drives the tile's `axi_in`
// manager port into the NoC; the tile's `axi_out` subordinate port from the
// NoC drives the core's AXI subordinate port (`io_axi_slave`, which maps
// ITCM / DTCM / CSR).
//
// CoreMiniAxi decodes its subordinate address space at local offsets
// (ITCM 0x0_0000, DTCM 0x1_0000, CSR 0x3_0000), while the NoC routes each
// tile at a distinct 256 KiB system window. Incoming subordinate addresses
// are therefore masked down to the local window with `LocalAddrMask`.

module coralnpu_floo_tile
  import floo_coralnpu_mesh_noc_pkg::*;
#(
  // Coral NPU local window: ITCM/DTCM/CSR all live below 256 KiB.
  parameter logic [31:0] LocalAddrMask = 32'h0003_FFFF
) (
  input  logic         clk_i,
  input  logic         rst_ni,
  input  logic         test_enable_i,
  // Core sideband
  input  logic [31:0]  boot_addr_i,
  input  logic         irq_i,
  output logic         halted_o,
  output logic         fault_o,
  output logic         wfi_o,
  // AXI manager port into the NoC (core -> network)
  output axi_in_req_t  axi_mgr_req_o,
  input  axi_in_rsp_t  axi_mgr_rsp_i,
  // AXI subordinate port from the NoC (network -> core ITCM/DTCM/CSR)
  input  axi_out_req_t axi_sbr_req_i,
  output axi_out_rsp_t axi_sbr_rsp_o
);

  CoreMiniAxi u_core (
    .io_aclk    (clk_i),
    .io_aresetn (rst_ni),
    .io_te      (test_enable_i),

    .io_boot_addr (boot_addr_i),
    .io_irq       (irq_i),
    .io_halted    (halted_o),
    .io_fault     (fault_o),
    .io_wfi       (wfi_o),

    // Debug module unused in the mesh; requests idle, responses drained.
    .io_dm_req_valid        (1'b0),
    .io_dm_req_bits_address (32'h0),
    .io_dm_req_bits_data    (32'h0),
    .io_dm_req_bits_op      (2'h0),
    .io_dm_req_ready        (/* unused */),
    .io_dm_rsp_valid        (/* unused */),
    .io_dm_rsp_ready        (1'b1),
    .io_dm_rsp_bits_data    (/* unused */),
    .io_dm_rsp_bits_op      (/* unused */),

    // Manager port: core -> NoC
    .io_axi_master_write_addr_valid       (axi_mgr_req_o.aw_valid),
    .io_axi_master_write_addr_ready       (axi_mgr_rsp_i.aw_ready),
    .io_axi_master_write_addr_bits_addr   (axi_mgr_req_o.aw.addr),
    .io_axi_master_write_addr_bits_prot   (axi_mgr_req_o.aw.prot),
    .io_axi_master_write_addr_bits_id     (axi_mgr_req_o.aw.id),
    .io_axi_master_write_addr_bits_len    (axi_mgr_req_o.aw.len),
    .io_axi_master_write_addr_bits_size   (axi_mgr_req_o.aw.size),
    .io_axi_master_write_addr_bits_burst  (axi_mgr_req_o.aw.burst),
    .io_axi_master_write_addr_bits_lock   (axi_mgr_req_o.aw.lock),
    .io_axi_master_write_addr_bits_cache  (axi_mgr_req_o.aw.cache),
    .io_axi_master_write_addr_bits_qos    (axi_mgr_req_o.aw.qos),
    .io_axi_master_write_addr_bits_region (axi_mgr_req_o.aw.region),
    .io_axi_master_write_data_valid       (axi_mgr_req_o.w_valid),
    .io_axi_master_write_data_ready       (axi_mgr_rsp_i.w_ready),
    .io_axi_master_write_data_bits_data   (axi_mgr_req_o.w.data),
    .io_axi_master_write_data_bits_strb   (axi_mgr_req_o.w.strb),
    .io_axi_master_write_data_bits_last   (axi_mgr_req_o.w.last),
    .io_axi_master_write_resp_valid       (axi_mgr_rsp_i.b_valid),
    .io_axi_master_write_resp_ready       (axi_mgr_req_o.b_ready),
    .io_axi_master_write_resp_bits_id     (axi_mgr_rsp_i.b.id),
    .io_axi_master_write_resp_bits_resp   (axi_mgr_rsp_i.b.resp),
    .io_axi_master_read_addr_valid        (axi_mgr_req_o.ar_valid),
    .io_axi_master_read_addr_ready        (axi_mgr_rsp_i.ar_ready),
    .io_axi_master_read_addr_bits_addr    (axi_mgr_req_o.ar.addr),
    .io_axi_master_read_addr_bits_prot    (axi_mgr_req_o.ar.prot),
    .io_axi_master_read_addr_bits_id      (axi_mgr_req_o.ar.id),
    .io_axi_master_read_addr_bits_len     (axi_mgr_req_o.ar.len),
    .io_axi_master_read_addr_bits_size    (axi_mgr_req_o.ar.size),
    .io_axi_master_read_addr_bits_burst   (axi_mgr_req_o.ar.burst),
    .io_axi_master_read_addr_bits_lock    (axi_mgr_req_o.ar.lock),
    .io_axi_master_read_addr_bits_cache   (axi_mgr_req_o.ar.cache),
    .io_axi_master_read_addr_bits_qos     (axi_mgr_req_o.ar.qos),
    .io_axi_master_read_addr_bits_region  (axi_mgr_req_o.ar.region),
    .io_axi_master_read_data_valid        (axi_mgr_rsp_i.r_valid),
    .io_axi_master_read_data_ready        (axi_mgr_req_o.r_ready),
    .io_axi_master_read_data_bits_data    (axi_mgr_rsp_i.r.data),
    .io_axi_master_read_data_bits_id      (axi_mgr_rsp_i.r.id),
    .io_axi_master_read_data_bits_resp    (axi_mgr_rsp_i.r.resp),
    .io_axi_master_read_data_bits_last    (axi_mgr_rsp_i.r.last),

    // Subordinate port: NoC -> core, address masked to the local window
    .io_axi_slave_write_addr_valid        (axi_sbr_req_i.aw_valid),
    .io_axi_slave_write_addr_ready        (axi_sbr_rsp_o.aw_ready),
    .io_axi_slave_write_addr_bits_addr    (axi_sbr_req_i.aw.addr & LocalAddrMask),
    .io_axi_slave_write_addr_bits_prot    (axi_sbr_req_i.aw.prot),
    .io_axi_slave_write_addr_bits_id      (axi_sbr_req_i.aw.id),
    .io_axi_slave_write_addr_bits_len     (axi_sbr_req_i.aw.len),
    .io_axi_slave_write_addr_bits_size    (axi_sbr_req_i.aw.size),
    .io_axi_slave_write_addr_bits_burst   (axi_sbr_req_i.aw.burst),
    .io_axi_slave_write_addr_bits_lock    (axi_sbr_req_i.aw.lock),
    .io_axi_slave_write_addr_bits_cache   (axi_sbr_req_i.aw.cache),
    .io_axi_slave_write_addr_bits_qos     (axi_sbr_req_i.aw.qos),
    .io_axi_slave_write_addr_bits_region  (axi_sbr_req_i.aw.region),
    .io_axi_slave_write_data_valid        (axi_sbr_req_i.w_valid),
    .io_axi_slave_write_data_ready        (axi_sbr_rsp_o.w_ready),
    .io_axi_slave_write_data_bits_data    (axi_sbr_req_i.w.data),
    .io_axi_slave_write_data_bits_strb    (axi_sbr_req_i.w.strb),
    .io_axi_slave_write_data_bits_last    (axi_sbr_req_i.w.last),
    .io_axi_slave_write_resp_valid        (axi_sbr_rsp_o.b_valid),
    .io_axi_slave_write_resp_ready        (axi_sbr_req_i.b_ready),
    .io_axi_slave_write_resp_bits_id      (axi_sbr_rsp_o.b.id),
    .io_axi_slave_write_resp_bits_resp    (axi_sbr_rsp_o.b.resp),
    .io_axi_slave_read_addr_valid         (axi_sbr_req_i.ar_valid),
    .io_axi_slave_read_addr_ready         (axi_sbr_rsp_o.ar_ready),
    .io_axi_slave_read_addr_bits_addr     (axi_sbr_req_i.ar.addr & LocalAddrMask),
    .io_axi_slave_read_addr_bits_prot     (axi_sbr_req_i.ar.prot),
    .io_axi_slave_read_addr_bits_id       (axi_sbr_req_i.ar.id),
    .io_axi_slave_read_addr_bits_len      (axi_sbr_req_i.ar.len),
    .io_axi_slave_read_addr_bits_size     (axi_sbr_req_i.ar.size),
    .io_axi_slave_read_addr_bits_burst    (axi_sbr_req_i.ar.burst),
    .io_axi_slave_read_addr_bits_lock     (axi_sbr_req_i.ar.lock),
    .io_axi_slave_read_addr_bits_cache    (axi_sbr_req_i.ar.cache),
    .io_axi_slave_read_addr_bits_qos      (axi_sbr_req_i.ar.qos),
    .io_axi_slave_read_addr_bits_region   (axi_sbr_req_i.ar.region),
    .io_axi_slave_read_data_valid         (axi_sbr_rsp_o.r_valid),
    .io_axi_slave_read_data_ready         (axi_sbr_req_i.r_ready),
    .io_axi_slave_read_data_bits_data     (axi_sbr_rsp_o.r.data),
    .io_axi_slave_read_data_bits_id       (axi_sbr_rsp_o.r.id),
    .io_axi_slave_read_data_bits_resp     (axi_sbr_rsp_o.r.resp),
    .io_axi_slave_read_data_bits_last     (axi_sbr_rsp_o.r.last)
  );

  // Fields the Coral NPU AXI interfaces do not carry.
  assign axi_mgr_req_o.aw.atop = '0;
  assign axi_mgr_req_o.aw.user = '0;
  assign axi_mgr_req_o.w.user  = '0;
  assign axi_mgr_req_o.ar.user = '0;
  assign axi_sbr_rsp_o.b.user  = '0;
  assign axi_sbr_rsp_o.r.user  = '0;

endmodule
