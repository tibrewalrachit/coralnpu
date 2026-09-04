// Port-accurate stub of the clustergen-generated snitch_cluster_wrapper for
// lint only. AXI port widths come from snitch_floo_hub_pkg, which mirrors
// the upstream default cluster configuration; the remaining ports use
// minimal stand-in widths, which is fine because the hub ties them off.
module snitch_cluster_wrapper
  import snitch_floo_hub_pkg::*;
#(
  parameter int unsigned NrCores = 9,
  parameter int unsigned NrHives = 1
) (
  input  logic                          clk_i,
  input  logic                          rst_ni,
  input  logic [NrCores-1:0]            debug_req_i,
  input  logic [NrCores-1:0]            meip_i,
  input  logic [NrCores-1:0]            mtip_i,
  input  logic [NrCores-1:0]            msip_i,
  input  logic [NrCores-1:0]            mxip_i,
  input  logic [31:0]                   hart_base_id_i,
  input  logic [SnAddrWidth-1:0]        cluster_base_addr_i,
  input  logic [SnAddrWidth-1:0]        cluster_base_offset_i,
  input  logic                          clk_d2_bypass_i,
  input  logic [5:0]                    sram_cfg_tcdm_i,
  input  logic [NrHives-1:0][5:0]       sram_cfg_icache_tag_i,
  input  logic [NrHives-1:0][5:0]       sram_cfg_icache_data_i,
  input  sn_narrow_in_req_t             narrow_in_req_i,
  output sn_narrow_in_rsp_t             narrow_in_resp_o,
  output sn_narrow_out_req_t            narrow_out_req_o,
  input  sn_narrow_out_rsp_t            narrow_out_resp_i,
  output sn_wide_out_req_t              wide_out_req_o,
  input  sn_wide_out_rsp_t              wide_out_resp_i,
  input  sn_wide_in_req_t               wide_in_req_i,
  output sn_wide_in_rsp_t               wide_in_resp_o,
  output logic [NrCores-1:0]            x_issue_req_o,
  input  logic [NrCores-1:0]            x_issue_resp_i,
  output logic [NrCores-1:0]            x_issue_valid_o,
  input  logic [NrCores-1:0]            x_issue_ready_i,
  output logic [NrCores-1:0]            x_register_o,
  output logic [NrCores-1:0]            x_register_valid_o,
  input  logic [NrCores-1:0]            x_register_ready_i,
  output logic [NrCores-1:0]            x_commit_o,
  output logic [NrCores-1:0]            x_commit_valid_o,
  input  logic [NrCores-1:0]            x_result_i,
  input  logic [NrCores-1:0]            x_result_valid_i,
  output logic [NrCores-1:0]            x_result_ready_o,
  output sn_narrow_out_req_t            narrow_ext_req_o,
  input  sn_narrow_out_rsp_t            narrow_ext_resp_i,
  input  logic                          tcdm_ext_req_i,
  output logic                          tcdm_ext_resp_o,
  input  logic                          dca_req_i,
  output logic                          dca_rsp_o
);
endmodule
