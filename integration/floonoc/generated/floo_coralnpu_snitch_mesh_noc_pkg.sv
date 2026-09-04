// Copyright 2026 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// AUTOMATICALLY GENERATED! DO NOT EDIT!

`include "axi/typedef.svh"
`include "floo_noc/typedef.svh"

package floo_coralnpu_snitch_mesh_noc_pkg;

  import floo_pkg::*;

  /////////////////////////////
  //   Endpoint Dimensions   //
  /////////////////////////////

  localparam int unsigned NumCoralWX = 1;
localparam int unsigned NumCoralWY = 3;
localparam int unsigned NumCoralEX = 1;
localparam int unsigned NumCoralEY = 3;


  /////////////////////
  //   Address Map   //
  /////////////////////

  typedef enum logic[3:0] {
    CoralWX0Y0 = 0,
    CoralWX0Y1 = 1,
    CoralWX0Y2 = 2,
    CoralEX0Y0 = 3,
    CoralEX0Y1 = 4,
    CoralEX0Y2 = 5,
    CoralN = 6,
    CoralS = 7,
    Snitch = 8,
    Host = 9,
    Mem = 10,
    NumEndpoints = 11} ep_id_e;



  typedef enum logic[3:0] {
    CoralWX0Y0SamIdx = 0,
    CoralWX0Y1SamIdx = 1,
    CoralWX0Y2SamIdx = 2,
    CoralEX0Y0SamIdx = 3,
    CoralEX0Y1SamIdx = 4,
    CoralEX0Y2SamIdx = 5,
    CoralNSamIdx = 6,
    CoralSSamIdx = 7,
    SnitchSamIdx = 8,
    MemSamIdx = 9} sam_idx_e;



  typedef logic[0:0] rob_idx_t;
typedef logic[0:0] port_id_t;
typedef logic[2:0] x_bits_t;
typedef logic[1:0] y_bits_t;
typedef struct packed {
    x_bits_t x;
    y_bits_t y;
    port_id_t port_id;
} id_t;

typedef logic route_t;


  typedef struct packed {
    id_t idx;
    id_t start_addr;
    id_t end_addr;
  } route_map_rule_t;

  localparam int unsigned SamNumRules = 10;

typedef struct packed {
    id_t idx;
    logic [31:0] start_addr;
    logic [31:0] end_addr;
} sam_rule_t;

localparam sam_rule_t[SamNumRules-1:0] Sam = '{
'{    idx: '{x: 4, y: 1, port_id: 0},
    start_addr: 32'h80000000,
    end_addr: 32'h81000000},// Mem
'{    idx: '{x: 2, y: 1, port_id: 0},
    start_addr: 32'h20000000,
    end_addr: 32'h20100000},// Snitch
'{    idx: '{x: 2, y: 0, port_id: 0},
    start_addr: 32'h10240000,
    end_addr: 32'h10280000},// CoralS
'{    idx: '{x: 2, y: 2, port_id: 0},
    start_addr: 32'h10200000,
    end_addr: 32'h10240000},// CoralN
'{    idx: '{x: 3, y: 2, port_id: 0},
    start_addr: 32'h10180000,
    end_addr: 32'h101c0000},// CoralEX0Y2
'{    idx: '{x: 3, y: 1, port_id: 0},
    start_addr: 32'h10140000,
    end_addr: 32'h10180000},// CoralEX0Y1
'{    idx: '{x: 3, y: 0, port_id: 0},
    start_addr: 32'h10100000,
    end_addr: 32'h10140000},// CoralEX0Y0
'{    idx: '{x: 1, y: 2, port_id: 0},
    start_addr: 32'h10080000,
    end_addr: 32'h100c0000},// CoralWX0Y2
'{    idx: '{x: 1, y: 1, port_id: 0},
    start_addr: 32'h10040000,
    end_addr: 32'h10080000},// CoralWX0Y1
'{    idx: '{x: 1, y: 0, port_id: 0},
    start_addr: 32'h10000000,
    end_addr: 32'h10040000} // CoralWX0Y0

};



  localparam route_cfg_t RouteCfg = '{    RouteAlgo: XYRouting,
    UseIdTable: 1'b1,
    XYAddrOffsetX: 32,
    XYAddrOffsetY: 35,
    IdAddrOffset: 0,
    NumSamRules: 10,
    NumRoutes: 0,
    CollectiveCfg: '{    OpCfg: '{    EnNarrowMulticast: 1'b0,
    EnWideMulticast: 1'b0,
    EnLsbAnd: 1'b0,
    EnFpAdd: 1'b0,
    EnFpMul: 1'b0,
    EnFpMin: 1'b0,
    EnFpMax: 1'b0,
    EnIntAdd: 1'b0,
    EnIntMul: 1'b0,
    EnIntMinS: 1'b0,
    EnIntMinU: 1'b0,
    EnIntMaxS: 1'b0,
    EnIntMaxU: 1'b0},
    NarrRedCfg: RedDefaultCfg,
    WideRedCfg: RedDefaultCfg}};

  

    typedef logic[31:0] axi_in_addr_t;
typedef logic[127:0] axi_in_data_t;
typedef logic[15:0] axi_in_strb_t;
typedef logic[5:0] axi_in_id_t;
typedef logic[0:0] axi_in_user_t;
`AXI_TYPEDEF_ALL_CT(axi_in,             axi_in_req_t,             axi_in_rsp_t,             axi_in_addr_t,             axi_in_id_t,             axi_in_data_t,             axi_in_strb_t,             axi_in_user_t)


    typedef logic[31:0] axi_out_addr_t;
typedef logic[127:0] axi_out_data_t;
typedef logic[15:0] axi_out_strb_t;
typedef logic[5:0] axi_out_id_t;
typedef logic[0:0] axi_out_user_t;
`AXI_TYPEDEF_ALL_CT(axi_out,             axi_out_req_t,             axi_out_rsp_t,             axi_out_addr_t,             axi_out_id_t,             axi_out_data_t,             axi_out_strb_t,             axi_out_user_t)



  `FLOO_TYPEDEF_HDR_T(hdr_t, id_t, id_t, axi_ch_e, rob_idx_t)
  localparam axi_cfg_t AxiCfg = '{    AddrWidth: 32,
    DataWidth: 128,
    InIdWidth: 6,
    OutIdWidth: 6,
    UserWidth: 1};
`FLOO_TYPEDEF_AXI_CHAN_ALL(axi, req, rsp, axi_in, AxiCfg, hdr_t)

`FLOO_TYPEDEF_AXI_LINK_ALL(req, rsp, req, rsp)


endpackage
