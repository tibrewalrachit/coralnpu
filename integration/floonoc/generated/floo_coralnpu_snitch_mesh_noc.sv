// Copyright 2026 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// AUTOMATICALLY GENERATED! DO NOT EDIT!

module floo_coralnpu_snitch_mesh_noc
  import floo_pkg::*;
  import floo_coralnpu_snitch_mesh_noc_pkg::*;
(
  input logic clk_i,
  input logic rst_ni,
  input logic test_enable_i,
  input axi_in_req_t             [2:0] coral_w_axi_in_req_i,
  output axi_in_rsp_t             [2:0] coral_w_axi_in_rsp_o,
  output axi_out_req_t             [2:0] coral_w_axi_out_req_o,
  input axi_out_rsp_t             [2:0] coral_w_axi_out_rsp_i,
  input axi_in_req_t             [2:0] coral_e_axi_in_req_i,
  output axi_in_rsp_t             [2:0] coral_e_axi_in_rsp_o,
  output axi_out_req_t             [2:0] coral_e_axi_out_req_o,
  input axi_out_rsp_t             [2:0] coral_e_axi_out_rsp_i,
  input axi_in_req_t              coral_n_axi_in_req_i,
  output axi_in_rsp_t              coral_n_axi_in_rsp_o,
  output axi_out_req_t              coral_n_axi_out_req_o,
  input axi_out_rsp_t              coral_n_axi_out_rsp_i,
  input axi_in_req_t              coral_s_axi_in_req_i,
  output axi_in_rsp_t              coral_s_axi_in_rsp_o,
  output axi_out_req_t              coral_s_axi_out_req_o,
  input axi_out_rsp_t              coral_s_axi_out_rsp_i,
  input axi_in_req_t              snitch_axi_in_req_i,
  output axi_in_rsp_t              snitch_axi_in_rsp_o,
  output axi_out_req_t              snitch_axi_out_req_o,
  input axi_out_rsp_t              snitch_axi_out_rsp_i,
  input axi_in_req_t              host_axi_in_req_i,
  output axi_in_rsp_t              host_axi_in_rsp_o,
  output axi_out_req_t              mem_axi_out_req_o,
  input axi_out_rsp_t              mem_axi_out_rsp_i

);

floo_req_t router_0_0_to_router_0_1_req;
floo_rsp_t router_0_1_to_router_0_0_rsp;

floo_req_t router_0_0_to_router_1_0_req;
floo_rsp_t router_1_0_to_router_0_0_rsp;

floo_req_t router_0_0_to_coral_w_ni_0_0_req;
floo_rsp_t coral_w_ni_0_0_to_router_0_0_rsp;

floo_req_t router_0_1_to_router_0_0_req;
floo_rsp_t router_0_0_to_router_0_1_rsp;

floo_req_t router_0_1_to_router_0_2_req;
floo_rsp_t router_0_2_to_router_0_1_rsp;

floo_req_t router_0_1_to_router_1_1_req;
floo_rsp_t router_1_1_to_router_0_1_rsp;

floo_req_t router_0_1_to_coral_w_ni_0_1_req;
floo_rsp_t coral_w_ni_0_1_to_router_0_1_rsp;

floo_req_t router_0_1_to_host_ni_req;
floo_rsp_t host_ni_to_router_0_1_rsp;

floo_req_t router_0_2_to_router_0_1_req;
floo_rsp_t router_0_1_to_router_0_2_rsp;

floo_req_t router_0_2_to_router_1_2_req;
floo_rsp_t router_1_2_to_router_0_2_rsp;

floo_req_t router_0_2_to_coral_w_ni_0_2_req;
floo_rsp_t coral_w_ni_0_2_to_router_0_2_rsp;

floo_req_t router_1_0_to_router_0_0_req;
floo_rsp_t router_0_0_to_router_1_0_rsp;

floo_req_t router_1_0_to_router_1_1_req;
floo_rsp_t router_1_1_to_router_1_0_rsp;

floo_req_t router_1_0_to_router_2_0_req;
floo_rsp_t router_2_0_to_router_1_0_rsp;

floo_req_t router_1_0_to_coral_s_ni_req;
floo_rsp_t coral_s_ni_to_router_1_0_rsp;

floo_req_t router_1_1_to_router_0_1_req;
floo_rsp_t router_0_1_to_router_1_1_rsp;

floo_req_t router_1_1_to_router_1_0_req;
floo_rsp_t router_1_0_to_router_1_1_rsp;

floo_req_t router_1_1_to_router_1_2_req;
floo_rsp_t router_1_2_to_router_1_1_rsp;

floo_req_t router_1_1_to_router_2_1_req;
floo_rsp_t router_2_1_to_router_1_1_rsp;

floo_req_t router_1_1_to_snitch_ni_req;
floo_rsp_t snitch_ni_to_router_1_1_rsp;

floo_req_t router_1_2_to_router_0_2_req;
floo_rsp_t router_0_2_to_router_1_2_rsp;

floo_req_t router_1_2_to_router_1_1_req;
floo_rsp_t router_1_1_to_router_1_2_rsp;

floo_req_t router_1_2_to_router_2_2_req;
floo_rsp_t router_2_2_to_router_1_2_rsp;

floo_req_t router_1_2_to_coral_n_ni_req;
floo_rsp_t coral_n_ni_to_router_1_2_rsp;

floo_req_t router_2_0_to_router_1_0_req;
floo_rsp_t router_1_0_to_router_2_0_rsp;

floo_req_t router_2_0_to_router_2_1_req;
floo_rsp_t router_2_1_to_router_2_0_rsp;

floo_req_t router_2_0_to_coral_e_ni_0_0_req;
floo_rsp_t coral_e_ni_0_0_to_router_2_0_rsp;

floo_req_t router_2_1_to_router_1_1_req;
floo_rsp_t router_1_1_to_router_2_1_rsp;

floo_req_t router_2_1_to_router_2_0_req;
floo_rsp_t router_2_0_to_router_2_1_rsp;

floo_req_t router_2_1_to_router_2_2_req;
floo_rsp_t router_2_2_to_router_2_1_rsp;

floo_req_t router_2_1_to_coral_e_ni_0_1_req;
floo_rsp_t coral_e_ni_0_1_to_router_2_1_rsp;

floo_req_t router_2_1_to_mem_ni_req;
floo_rsp_t mem_ni_to_router_2_1_rsp;

floo_req_t router_2_2_to_router_1_2_req;
floo_rsp_t router_1_2_to_router_2_2_rsp;

floo_req_t router_2_2_to_router_2_1_req;
floo_rsp_t router_2_1_to_router_2_2_rsp;

floo_req_t router_2_2_to_coral_e_ni_0_2_req;
floo_rsp_t coral_e_ni_0_2_to_router_2_2_rsp;

floo_req_t coral_w_ni_0_0_to_router_0_0_req;
floo_rsp_t router_0_0_to_coral_w_ni_0_0_rsp;

floo_req_t coral_w_ni_0_1_to_router_0_1_req;
floo_rsp_t router_0_1_to_coral_w_ni_0_1_rsp;

floo_req_t coral_w_ni_0_2_to_router_0_2_req;
floo_rsp_t router_0_2_to_coral_w_ni_0_2_rsp;

floo_req_t coral_e_ni_0_0_to_router_2_0_req;
floo_rsp_t router_2_0_to_coral_e_ni_0_0_rsp;

floo_req_t coral_e_ni_0_1_to_router_2_1_req;
floo_rsp_t router_2_1_to_coral_e_ni_0_1_rsp;

floo_req_t coral_e_ni_0_2_to_router_2_2_req;
floo_rsp_t router_2_2_to_coral_e_ni_0_2_rsp;

floo_req_t coral_n_ni_to_router_1_2_req;
floo_rsp_t router_1_2_to_coral_n_ni_rsp;

floo_req_t coral_s_ni_to_router_1_0_req;
floo_rsp_t router_1_0_to_coral_s_ni_rsp;

floo_req_t snitch_ni_to_router_1_1_req;
floo_rsp_t router_1_1_to_snitch_ni_rsp;

floo_req_t host_ni_to_router_0_1_req;
floo_rsp_t router_0_1_to_host_ni_rsp;

floo_req_t mem_ni_to_router_2_1_req;
floo_rsp_t router_2_1_to_mem_ni_rsp;



  localparam id_t CORAL_W_NI_0_0_ID = '{x: 1, y: 0, port_id: 0};

floo_axi_chimney  #(
  .AxiCfg(AxiCfg),
  .ChimneyCfg(set_ports(ChimneyDefaultCfg, 1'b1, 1'b1)),
  .RouteCfg(RouteCfg),
  .id_t(id_t),
  .rob_idx_t(rob_idx_t),
  .hdr_t  (hdr_t),
  .sam_rule_t(sam_rule_t),
  .Sam(Sam),
  .axi_in_req_t(axi_in_req_t),
  .axi_in_rsp_t(axi_in_rsp_t),
  .axi_out_req_t(axi_out_req_t),
  .axi_out_rsp_t(axi_out_rsp_t),
  .floo_req_t(floo_req_t),
  .floo_rsp_t(floo_rsp_t)
) coral_w_ni_0_0 (
  .clk_i,
  .rst_ni,
  .test_enable_i,
  .sram_cfg_i ( '0 ),
  .axi_in_req_i  ( coral_w_axi_in_req_i[0] ),
  .axi_in_rsp_o  ( coral_w_axi_in_rsp_o[0] ),
  .axi_out_req_o ( coral_w_axi_out_req_o[0] ),
  .axi_out_rsp_i ( coral_w_axi_out_rsp_i[0] ),
  .id_i             ( CORAL_W_NI_0_0_ID       ),
  .route_table_i    ( '0                          ),
  .floo_req_o       ( coral_w_ni_0_0_to_router_0_0_req   ),
  .floo_rsp_i       ( router_0_0_to_coral_w_ni_0_0_rsp   ),
  .floo_req_i       ( router_0_0_to_coral_w_ni_0_0_req   ),
  .floo_rsp_o       ( coral_w_ni_0_0_to_router_0_0_rsp   )
);

  localparam id_t CORAL_W_NI_0_1_ID = '{x: 1, y: 1, port_id: 0};

floo_axi_chimney  #(
  .AxiCfg(AxiCfg),
  .ChimneyCfg(set_ports(ChimneyDefaultCfg, 1'b1, 1'b1)),
  .RouteCfg(RouteCfg),
  .id_t(id_t),
  .rob_idx_t(rob_idx_t),
  .hdr_t  (hdr_t),
  .sam_rule_t(sam_rule_t),
  .Sam(Sam),
  .axi_in_req_t(axi_in_req_t),
  .axi_in_rsp_t(axi_in_rsp_t),
  .axi_out_req_t(axi_out_req_t),
  .axi_out_rsp_t(axi_out_rsp_t),
  .floo_req_t(floo_req_t),
  .floo_rsp_t(floo_rsp_t)
) coral_w_ni_0_1 (
  .clk_i,
  .rst_ni,
  .test_enable_i,
  .sram_cfg_i ( '0 ),
  .axi_in_req_i  ( coral_w_axi_in_req_i[1] ),
  .axi_in_rsp_o  ( coral_w_axi_in_rsp_o[1] ),
  .axi_out_req_o ( coral_w_axi_out_req_o[1] ),
  .axi_out_rsp_i ( coral_w_axi_out_rsp_i[1] ),
  .id_i             ( CORAL_W_NI_0_1_ID       ),
  .route_table_i    ( '0                          ),
  .floo_req_o       ( coral_w_ni_0_1_to_router_0_1_req   ),
  .floo_rsp_i       ( router_0_1_to_coral_w_ni_0_1_rsp   ),
  .floo_req_i       ( router_0_1_to_coral_w_ni_0_1_req   ),
  .floo_rsp_o       ( coral_w_ni_0_1_to_router_0_1_rsp   )
);

  localparam id_t CORAL_W_NI_0_2_ID = '{x: 1, y: 2, port_id: 0};

floo_axi_chimney  #(
  .AxiCfg(AxiCfg),
  .ChimneyCfg(set_ports(ChimneyDefaultCfg, 1'b1, 1'b1)),
  .RouteCfg(RouteCfg),
  .id_t(id_t),
  .rob_idx_t(rob_idx_t),
  .hdr_t  (hdr_t),
  .sam_rule_t(sam_rule_t),
  .Sam(Sam),
  .axi_in_req_t(axi_in_req_t),
  .axi_in_rsp_t(axi_in_rsp_t),
  .axi_out_req_t(axi_out_req_t),
  .axi_out_rsp_t(axi_out_rsp_t),
  .floo_req_t(floo_req_t),
  .floo_rsp_t(floo_rsp_t)
) coral_w_ni_0_2 (
  .clk_i,
  .rst_ni,
  .test_enable_i,
  .sram_cfg_i ( '0 ),
  .axi_in_req_i  ( coral_w_axi_in_req_i[2] ),
  .axi_in_rsp_o  ( coral_w_axi_in_rsp_o[2] ),
  .axi_out_req_o ( coral_w_axi_out_req_o[2] ),
  .axi_out_rsp_i ( coral_w_axi_out_rsp_i[2] ),
  .id_i             ( CORAL_W_NI_0_2_ID       ),
  .route_table_i    ( '0                          ),
  .floo_req_o       ( coral_w_ni_0_2_to_router_0_2_req   ),
  .floo_rsp_i       ( router_0_2_to_coral_w_ni_0_2_rsp   ),
  .floo_req_i       ( router_0_2_to_coral_w_ni_0_2_req   ),
  .floo_rsp_o       ( coral_w_ni_0_2_to_router_0_2_rsp   )
);

  localparam id_t CORAL_E_NI_0_0_ID = '{x: 3, y: 0, port_id: 0};

floo_axi_chimney  #(
  .AxiCfg(AxiCfg),
  .ChimneyCfg(set_ports(ChimneyDefaultCfg, 1'b1, 1'b1)),
  .RouteCfg(RouteCfg),
  .id_t(id_t),
  .rob_idx_t(rob_idx_t),
  .hdr_t  (hdr_t),
  .sam_rule_t(sam_rule_t),
  .Sam(Sam),
  .axi_in_req_t(axi_in_req_t),
  .axi_in_rsp_t(axi_in_rsp_t),
  .axi_out_req_t(axi_out_req_t),
  .axi_out_rsp_t(axi_out_rsp_t),
  .floo_req_t(floo_req_t),
  .floo_rsp_t(floo_rsp_t)
) coral_e_ni_0_0 (
  .clk_i,
  .rst_ni,
  .test_enable_i,
  .sram_cfg_i ( '0 ),
  .axi_in_req_i  ( coral_e_axi_in_req_i[0] ),
  .axi_in_rsp_o  ( coral_e_axi_in_rsp_o[0] ),
  .axi_out_req_o ( coral_e_axi_out_req_o[0] ),
  .axi_out_rsp_i ( coral_e_axi_out_rsp_i[0] ),
  .id_i             ( CORAL_E_NI_0_0_ID       ),
  .route_table_i    ( '0                          ),
  .floo_req_o       ( coral_e_ni_0_0_to_router_2_0_req   ),
  .floo_rsp_i       ( router_2_0_to_coral_e_ni_0_0_rsp   ),
  .floo_req_i       ( router_2_0_to_coral_e_ni_0_0_req   ),
  .floo_rsp_o       ( coral_e_ni_0_0_to_router_2_0_rsp   )
);

  localparam id_t CORAL_E_NI_0_1_ID = '{x: 3, y: 1, port_id: 0};

floo_axi_chimney  #(
  .AxiCfg(AxiCfg),
  .ChimneyCfg(set_ports(ChimneyDefaultCfg, 1'b1, 1'b1)),
  .RouteCfg(RouteCfg),
  .id_t(id_t),
  .rob_idx_t(rob_idx_t),
  .hdr_t  (hdr_t),
  .sam_rule_t(sam_rule_t),
  .Sam(Sam),
  .axi_in_req_t(axi_in_req_t),
  .axi_in_rsp_t(axi_in_rsp_t),
  .axi_out_req_t(axi_out_req_t),
  .axi_out_rsp_t(axi_out_rsp_t),
  .floo_req_t(floo_req_t),
  .floo_rsp_t(floo_rsp_t)
) coral_e_ni_0_1 (
  .clk_i,
  .rst_ni,
  .test_enable_i,
  .sram_cfg_i ( '0 ),
  .axi_in_req_i  ( coral_e_axi_in_req_i[1] ),
  .axi_in_rsp_o  ( coral_e_axi_in_rsp_o[1] ),
  .axi_out_req_o ( coral_e_axi_out_req_o[1] ),
  .axi_out_rsp_i ( coral_e_axi_out_rsp_i[1] ),
  .id_i             ( CORAL_E_NI_0_1_ID       ),
  .route_table_i    ( '0                          ),
  .floo_req_o       ( coral_e_ni_0_1_to_router_2_1_req   ),
  .floo_rsp_i       ( router_2_1_to_coral_e_ni_0_1_rsp   ),
  .floo_req_i       ( router_2_1_to_coral_e_ni_0_1_req   ),
  .floo_rsp_o       ( coral_e_ni_0_1_to_router_2_1_rsp   )
);

  localparam id_t CORAL_E_NI_0_2_ID = '{x: 3, y: 2, port_id: 0};

floo_axi_chimney  #(
  .AxiCfg(AxiCfg),
  .ChimneyCfg(set_ports(ChimneyDefaultCfg, 1'b1, 1'b1)),
  .RouteCfg(RouteCfg),
  .id_t(id_t),
  .rob_idx_t(rob_idx_t),
  .hdr_t  (hdr_t),
  .sam_rule_t(sam_rule_t),
  .Sam(Sam),
  .axi_in_req_t(axi_in_req_t),
  .axi_in_rsp_t(axi_in_rsp_t),
  .axi_out_req_t(axi_out_req_t),
  .axi_out_rsp_t(axi_out_rsp_t),
  .floo_req_t(floo_req_t),
  .floo_rsp_t(floo_rsp_t)
) coral_e_ni_0_2 (
  .clk_i,
  .rst_ni,
  .test_enable_i,
  .sram_cfg_i ( '0 ),
  .axi_in_req_i  ( coral_e_axi_in_req_i[2] ),
  .axi_in_rsp_o  ( coral_e_axi_in_rsp_o[2] ),
  .axi_out_req_o ( coral_e_axi_out_req_o[2] ),
  .axi_out_rsp_i ( coral_e_axi_out_rsp_i[2] ),
  .id_i             ( CORAL_E_NI_0_2_ID       ),
  .route_table_i    ( '0                          ),
  .floo_req_o       ( coral_e_ni_0_2_to_router_2_2_req   ),
  .floo_rsp_i       ( router_2_2_to_coral_e_ni_0_2_rsp   ),
  .floo_req_i       ( router_2_2_to_coral_e_ni_0_2_req   ),
  .floo_rsp_o       ( coral_e_ni_0_2_to_router_2_2_rsp   )
);

  localparam id_t CORAL_N_NI_ID = '{x: 2, y: 2, port_id: 0};

floo_axi_chimney  #(
  .AxiCfg(AxiCfg),
  .ChimneyCfg(set_ports(ChimneyDefaultCfg, 1'b1, 1'b1)),
  .RouteCfg(RouteCfg),
  .id_t(id_t),
  .rob_idx_t(rob_idx_t),
  .hdr_t  (hdr_t),
  .sam_rule_t(sam_rule_t),
  .Sam(Sam),
  .axi_in_req_t(axi_in_req_t),
  .axi_in_rsp_t(axi_in_rsp_t),
  .axi_out_req_t(axi_out_req_t),
  .axi_out_rsp_t(axi_out_rsp_t),
  .floo_req_t(floo_req_t),
  .floo_rsp_t(floo_rsp_t)
) coral_n_ni (
  .clk_i,
  .rst_ni,
  .test_enable_i,
  .sram_cfg_i ( '0 ),
  .axi_in_req_i  ( coral_n_axi_in_req_i ),
  .axi_in_rsp_o  ( coral_n_axi_in_rsp_o ),
  .axi_out_req_o ( coral_n_axi_out_req_o ),
  .axi_out_rsp_i ( coral_n_axi_out_rsp_i ),
  .id_i             ( CORAL_N_NI_ID       ),
  .route_table_i    ( '0                          ),
  .floo_req_o       ( coral_n_ni_to_router_1_2_req   ),
  .floo_rsp_i       ( router_1_2_to_coral_n_ni_rsp   ),
  .floo_req_i       ( router_1_2_to_coral_n_ni_req   ),
  .floo_rsp_o       ( coral_n_ni_to_router_1_2_rsp   )
);

  localparam id_t CORAL_S_NI_ID = '{x: 2, y: 0, port_id: 0};

floo_axi_chimney  #(
  .AxiCfg(AxiCfg),
  .ChimneyCfg(set_ports(ChimneyDefaultCfg, 1'b1, 1'b1)),
  .RouteCfg(RouteCfg),
  .id_t(id_t),
  .rob_idx_t(rob_idx_t),
  .hdr_t  (hdr_t),
  .sam_rule_t(sam_rule_t),
  .Sam(Sam),
  .axi_in_req_t(axi_in_req_t),
  .axi_in_rsp_t(axi_in_rsp_t),
  .axi_out_req_t(axi_out_req_t),
  .axi_out_rsp_t(axi_out_rsp_t),
  .floo_req_t(floo_req_t),
  .floo_rsp_t(floo_rsp_t)
) coral_s_ni (
  .clk_i,
  .rst_ni,
  .test_enable_i,
  .sram_cfg_i ( '0 ),
  .axi_in_req_i  ( coral_s_axi_in_req_i ),
  .axi_in_rsp_o  ( coral_s_axi_in_rsp_o ),
  .axi_out_req_o ( coral_s_axi_out_req_o ),
  .axi_out_rsp_i ( coral_s_axi_out_rsp_i ),
  .id_i             ( CORAL_S_NI_ID       ),
  .route_table_i    ( '0                          ),
  .floo_req_o       ( coral_s_ni_to_router_1_0_req   ),
  .floo_rsp_i       ( router_1_0_to_coral_s_ni_rsp   ),
  .floo_req_i       ( router_1_0_to_coral_s_ni_req   ),
  .floo_rsp_o       ( coral_s_ni_to_router_1_0_rsp   )
);

  localparam id_t SNITCH_NI_ID = '{x: 2, y: 1, port_id: 0};

floo_axi_chimney  #(
  .AxiCfg(AxiCfg),
  .ChimneyCfg(set_ports(ChimneyDefaultCfg, 1'b1, 1'b1)),
  .RouteCfg(RouteCfg),
  .id_t(id_t),
  .rob_idx_t(rob_idx_t),
  .hdr_t  (hdr_t),
  .sam_rule_t(sam_rule_t),
  .Sam(Sam),
  .axi_in_req_t(axi_in_req_t),
  .axi_in_rsp_t(axi_in_rsp_t),
  .axi_out_req_t(axi_out_req_t),
  .axi_out_rsp_t(axi_out_rsp_t),
  .floo_req_t(floo_req_t),
  .floo_rsp_t(floo_rsp_t)
) snitch_ni (
  .clk_i,
  .rst_ni,
  .test_enable_i,
  .sram_cfg_i ( '0 ),
  .axi_in_req_i  ( snitch_axi_in_req_i ),
  .axi_in_rsp_o  ( snitch_axi_in_rsp_o ),
  .axi_out_req_o ( snitch_axi_out_req_o ),
  .axi_out_rsp_i ( snitch_axi_out_rsp_i ),
  .id_i             ( SNITCH_NI_ID       ),
  .route_table_i    ( '0                          ),
  .floo_req_o       ( snitch_ni_to_router_1_1_req   ),
  .floo_rsp_i       ( router_1_1_to_snitch_ni_rsp   ),
  .floo_req_i       ( router_1_1_to_snitch_ni_req   ),
  .floo_rsp_o       ( snitch_ni_to_router_1_1_rsp   )
);

  localparam id_t HOST_NI_ID = '{x: 0, y: 1, port_id: 0};

floo_axi_chimney  #(
  .AxiCfg(AxiCfg),
  .ChimneyCfg(set_ports(ChimneyDefaultCfg, 1'b0, 1'b1)),
  .RouteCfg(RouteCfg),
  .id_t(id_t),
  .rob_idx_t(rob_idx_t),
  .hdr_t  (hdr_t),
  .sam_rule_t(sam_rule_t),
  .Sam(Sam),
  .axi_in_req_t(axi_in_req_t),
  .axi_in_rsp_t(axi_in_rsp_t),
  .axi_out_req_t(axi_out_req_t),
  .axi_out_rsp_t(axi_out_rsp_t),
  .floo_req_t(floo_req_t),
  .floo_rsp_t(floo_rsp_t)
) host_ni (
  .clk_i,
  .rst_ni,
  .test_enable_i,
  .sram_cfg_i ( '0 ),
  .axi_in_req_i  ( host_axi_in_req_i ),
  .axi_in_rsp_o  ( host_axi_in_rsp_o ),
  .axi_out_req_o (    ),
  .axi_out_rsp_i ( '0 ),
  .id_i             ( HOST_NI_ID       ),
  .route_table_i    ( '0                          ),
  .floo_req_o       ( host_ni_to_router_0_1_req   ),
  .floo_rsp_i       ( router_0_1_to_host_ni_rsp   ),
  .floo_req_i       ( router_0_1_to_host_ni_req   ),
  .floo_rsp_o       ( host_ni_to_router_0_1_rsp   )
);

  localparam id_t MEM_NI_ID = '{x: 4, y: 1, port_id: 0};

floo_axi_chimney  #(
  .AxiCfg(AxiCfg),
  .ChimneyCfg(set_ports(ChimneyDefaultCfg, 1'b1, 1'b0)),
  .RouteCfg(RouteCfg),
  .id_t(id_t),
  .rob_idx_t(rob_idx_t),
  .hdr_t  (hdr_t),
  .sam_rule_t(sam_rule_t),
  .Sam(Sam),
  .axi_in_req_t(axi_in_req_t),
  .axi_in_rsp_t(axi_in_rsp_t),
  .axi_out_req_t(axi_out_req_t),
  .axi_out_rsp_t(axi_out_rsp_t),
  .floo_req_t(floo_req_t),
  .floo_rsp_t(floo_rsp_t)
) mem_ni (
  .clk_i,
  .rst_ni,
  .test_enable_i,
  .sram_cfg_i ( '0 ),
  .axi_in_req_i  ( '0 ),
  .axi_in_rsp_o  (    ),
  .axi_out_req_o ( mem_axi_out_req_o ),
  .axi_out_rsp_i ( mem_axi_out_rsp_i ),
  .id_i             ( MEM_NI_ID       ),
  .route_table_i    ( '0                          ),
  .floo_req_o       ( mem_ni_to_router_2_1_req   ),
  .floo_rsp_i       ( router_2_1_to_mem_ni_rsp   ),
  .floo_req_i       ( router_2_1_to_mem_ni_req   ),
  .floo_rsp_o       ( mem_ni_to_router_2_1_rsp   )
);


floo_req_t [4:0] router_0_0_req_in;
floo_rsp_t [4:0] router_0_0_rsp_out;
floo_req_t [4:0] router_0_0_req_out;
floo_rsp_t [4:0] router_0_0_rsp_in;

    assign router_0_0_req_in[0] = router_0_1_to_router_0_0_req;
    assign router_0_0_req_in[1] = router_1_0_to_router_0_0_req;
    assign router_0_0_req_in[2] = '0;
    assign router_0_0_req_in[3] = '0;
    assign router_0_0_req_in[4] = coral_w_ni_0_0_to_router_0_0_req;

    assign router_0_0_to_router_0_1_rsp = router_0_0_rsp_out[0];
    assign router_0_0_to_router_1_0_rsp = router_0_0_rsp_out[1];
    assign router_0_0_to_coral_w_ni_0_0_rsp = router_0_0_rsp_out[4];

    assign router_0_0_to_router_0_1_req = router_0_0_req_out[0];
    assign router_0_0_to_router_1_0_req = router_0_0_req_out[1];
    assign router_0_0_to_coral_w_ni_0_0_req = router_0_0_req_out[4];

    assign router_0_0_rsp_in[0] = router_0_1_to_router_0_0_rsp;
    assign router_0_0_rsp_in[1] = router_1_0_to_router_0_0_rsp;
    assign router_0_0_rsp_in[2] = '0;
    assign router_0_0_rsp_in[3] = '0;
    assign router_0_0_rsp_in[4] = coral_w_ni_0_0_to_router_0_0_rsp;

  localparam id_t ROUTER_0_0_ID = '{x: 1, y: 0, port_id: 0};

floo_axi_router #(
  .AxiCfg(AxiCfg),
  .RouteAlgo (XYRouting),
  .NumRoutes (5),
  .NumInputs (5),
  .NumOutputs (5),
  .InFifoDepth (2),
  .OutFifoDepth (2),
  .id_t(id_t),
  .hdr_t(hdr_t),
  .floo_req_t(floo_req_t),
  .floo_rsp_t(floo_rsp_t)
) router_0_0 (
  .clk_i,
  .rst_ni,
  .test_enable_i,
  .id_i (ROUTER_0_0_ID),
  .id_route_map_i ('0),
  .floo_req_i (router_0_0_req_in),
  .floo_rsp_o (router_0_0_rsp_out),
  .floo_req_o (router_0_0_req_out),
  .floo_rsp_i (router_0_0_rsp_in)
);


floo_req_t [4:0] router_0_1_req_in;
floo_rsp_t [4:0] router_0_1_rsp_out;
floo_req_t [4:0] router_0_1_req_out;
floo_rsp_t [4:0] router_0_1_rsp_in;

    assign router_0_1_req_in[0] = router_0_2_to_router_0_1_req;
    assign router_0_1_req_in[1] = router_1_1_to_router_0_1_req;
    assign router_0_1_req_in[2] = router_0_0_to_router_0_1_req;
    assign router_0_1_req_in[3] = host_ni_to_router_0_1_req;
    assign router_0_1_req_in[4] = coral_w_ni_0_1_to_router_0_1_req;

    assign router_0_1_to_router_0_2_rsp = router_0_1_rsp_out[0];
    assign router_0_1_to_router_1_1_rsp = router_0_1_rsp_out[1];
    assign router_0_1_to_router_0_0_rsp = router_0_1_rsp_out[2];
    assign router_0_1_to_host_ni_rsp = router_0_1_rsp_out[3];
    assign router_0_1_to_coral_w_ni_0_1_rsp = router_0_1_rsp_out[4];

    assign router_0_1_to_router_0_2_req = router_0_1_req_out[0];
    assign router_0_1_to_router_1_1_req = router_0_1_req_out[1];
    assign router_0_1_to_router_0_0_req = router_0_1_req_out[2];
    assign router_0_1_to_host_ni_req = router_0_1_req_out[3];
    assign router_0_1_to_coral_w_ni_0_1_req = router_0_1_req_out[4];

    assign router_0_1_rsp_in[0] = router_0_2_to_router_0_1_rsp;
    assign router_0_1_rsp_in[1] = router_1_1_to_router_0_1_rsp;
    assign router_0_1_rsp_in[2] = router_0_0_to_router_0_1_rsp;
    assign router_0_1_rsp_in[3] = host_ni_to_router_0_1_rsp;
    assign router_0_1_rsp_in[4] = coral_w_ni_0_1_to_router_0_1_rsp;

  localparam id_t ROUTER_0_1_ID = '{x: 1, y: 1, port_id: 0};

floo_axi_router #(
  .AxiCfg(AxiCfg),
  .RouteAlgo (XYRouting),
  .NumRoutes (5),
  .NumInputs (5),
  .NumOutputs (5),
  .InFifoDepth (2),
  .OutFifoDepth (2),
  .id_t(id_t),
  .hdr_t(hdr_t),
  .floo_req_t(floo_req_t),
  .floo_rsp_t(floo_rsp_t)
) router_0_1 (
  .clk_i,
  .rst_ni,
  .test_enable_i,
  .id_i (ROUTER_0_1_ID),
  .id_route_map_i ('0),
  .floo_req_i (router_0_1_req_in),
  .floo_rsp_o (router_0_1_rsp_out),
  .floo_req_o (router_0_1_req_out),
  .floo_rsp_i (router_0_1_rsp_in)
);


floo_req_t [4:0] router_0_2_req_in;
floo_rsp_t [4:0] router_0_2_rsp_out;
floo_req_t [4:0] router_0_2_req_out;
floo_rsp_t [4:0] router_0_2_rsp_in;

    assign router_0_2_req_in[0] = '0;
    assign router_0_2_req_in[1] = router_1_2_to_router_0_2_req;
    assign router_0_2_req_in[2] = router_0_1_to_router_0_2_req;
    assign router_0_2_req_in[3] = '0;
    assign router_0_2_req_in[4] = coral_w_ni_0_2_to_router_0_2_req;

    assign router_0_2_to_router_1_2_rsp = router_0_2_rsp_out[1];
    assign router_0_2_to_router_0_1_rsp = router_0_2_rsp_out[2];
    assign router_0_2_to_coral_w_ni_0_2_rsp = router_0_2_rsp_out[4];

    assign router_0_2_to_router_1_2_req = router_0_2_req_out[1];
    assign router_0_2_to_router_0_1_req = router_0_2_req_out[2];
    assign router_0_2_to_coral_w_ni_0_2_req = router_0_2_req_out[4];

    assign router_0_2_rsp_in[0] = '0;
    assign router_0_2_rsp_in[1] = router_1_2_to_router_0_2_rsp;
    assign router_0_2_rsp_in[2] = router_0_1_to_router_0_2_rsp;
    assign router_0_2_rsp_in[3] = '0;
    assign router_0_2_rsp_in[4] = coral_w_ni_0_2_to_router_0_2_rsp;

  localparam id_t ROUTER_0_2_ID = '{x: 1, y: 2, port_id: 0};

floo_axi_router #(
  .AxiCfg(AxiCfg),
  .RouteAlgo (XYRouting),
  .NumRoutes (5),
  .NumInputs (5),
  .NumOutputs (5),
  .InFifoDepth (2),
  .OutFifoDepth (2),
  .id_t(id_t),
  .hdr_t(hdr_t),
  .floo_req_t(floo_req_t),
  .floo_rsp_t(floo_rsp_t)
) router_0_2 (
  .clk_i,
  .rst_ni,
  .test_enable_i,
  .id_i (ROUTER_0_2_ID),
  .id_route_map_i ('0),
  .floo_req_i (router_0_2_req_in),
  .floo_rsp_o (router_0_2_rsp_out),
  .floo_req_o (router_0_2_req_out),
  .floo_rsp_i (router_0_2_rsp_in)
);


floo_req_t [4:0] router_1_0_req_in;
floo_rsp_t [4:0] router_1_0_rsp_out;
floo_req_t [4:0] router_1_0_req_out;
floo_rsp_t [4:0] router_1_0_rsp_in;

    assign router_1_0_req_in[0] = router_1_1_to_router_1_0_req;
    assign router_1_0_req_in[1] = router_2_0_to_router_1_0_req;
    assign router_1_0_req_in[2] = '0;
    assign router_1_0_req_in[3] = router_0_0_to_router_1_0_req;
    assign router_1_0_req_in[4] = coral_s_ni_to_router_1_0_req;

    assign router_1_0_to_router_1_1_rsp = router_1_0_rsp_out[0];
    assign router_1_0_to_router_2_0_rsp = router_1_0_rsp_out[1];
    assign router_1_0_to_router_0_0_rsp = router_1_0_rsp_out[3];
    assign router_1_0_to_coral_s_ni_rsp = router_1_0_rsp_out[4];

    assign router_1_0_to_router_1_1_req = router_1_0_req_out[0];
    assign router_1_0_to_router_2_0_req = router_1_0_req_out[1];
    assign router_1_0_to_router_0_0_req = router_1_0_req_out[3];
    assign router_1_0_to_coral_s_ni_req = router_1_0_req_out[4];

    assign router_1_0_rsp_in[0] = router_1_1_to_router_1_0_rsp;
    assign router_1_0_rsp_in[1] = router_2_0_to_router_1_0_rsp;
    assign router_1_0_rsp_in[2] = '0;
    assign router_1_0_rsp_in[3] = router_0_0_to_router_1_0_rsp;
    assign router_1_0_rsp_in[4] = coral_s_ni_to_router_1_0_rsp;

  localparam id_t ROUTER_1_0_ID = '{x: 2, y: 0, port_id: 0};

floo_axi_router #(
  .AxiCfg(AxiCfg),
  .RouteAlgo (XYRouting),
  .NumRoutes (5),
  .NumInputs (5),
  .NumOutputs (5),
  .InFifoDepth (2),
  .OutFifoDepth (2),
  .id_t(id_t),
  .hdr_t(hdr_t),
  .floo_req_t(floo_req_t),
  .floo_rsp_t(floo_rsp_t)
) router_1_0 (
  .clk_i,
  .rst_ni,
  .test_enable_i,
  .id_i (ROUTER_1_0_ID),
  .id_route_map_i ('0),
  .floo_req_i (router_1_0_req_in),
  .floo_rsp_o (router_1_0_rsp_out),
  .floo_req_o (router_1_0_req_out),
  .floo_rsp_i (router_1_0_rsp_in)
);


floo_req_t [4:0] router_1_1_req_in;
floo_rsp_t [4:0] router_1_1_rsp_out;
floo_req_t [4:0] router_1_1_req_out;
floo_rsp_t [4:0] router_1_1_rsp_in;

    assign router_1_1_req_in[0] = router_1_2_to_router_1_1_req;
    assign router_1_1_req_in[1] = router_2_1_to_router_1_1_req;
    assign router_1_1_req_in[2] = router_1_0_to_router_1_1_req;
    assign router_1_1_req_in[3] = router_0_1_to_router_1_1_req;
    assign router_1_1_req_in[4] = snitch_ni_to_router_1_1_req;

    assign router_1_1_to_router_1_2_rsp = router_1_1_rsp_out[0];
    assign router_1_1_to_router_2_1_rsp = router_1_1_rsp_out[1];
    assign router_1_1_to_router_1_0_rsp = router_1_1_rsp_out[2];
    assign router_1_1_to_router_0_1_rsp = router_1_1_rsp_out[3];
    assign router_1_1_to_snitch_ni_rsp = router_1_1_rsp_out[4];

    assign router_1_1_to_router_1_2_req = router_1_1_req_out[0];
    assign router_1_1_to_router_2_1_req = router_1_1_req_out[1];
    assign router_1_1_to_router_1_0_req = router_1_1_req_out[2];
    assign router_1_1_to_router_0_1_req = router_1_1_req_out[3];
    assign router_1_1_to_snitch_ni_req = router_1_1_req_out[4];

    assign router_1_1_rsp_in[0] = router_1_2_to_router_1_1_rsp;
    assign router_1_1_rsp_in[1] = router_2_1_to_router_1_1_rsp;
    assign router_1_1_rsp_in[2] = router_1_0_to_router_1_1_rsp;
    assign router_1_1_rsp_in[3] = router_0_1_to_router_1_1_rsp;
    assign router_1_1_rsp_in[4] = snitch_ni_to_router_1_1_rsp;

  localparam id_t ROUTER_1_1_ID = '{x: 2, y: 1, port_id: 0};

floo_axi_router #(
  .AxiCfg(AxiCfg),
  .RouteAlgo (XYRouting),
  .NumRoutes (5),
  .NumInputs (5),
  .NumOutputs (5),
  .InFifoDepth (2),
  .OutFifoDepth (2),
  .id_t(id_t),
  .hdr_t(hdr_t),
  .floo_req_t(floo_req_t),
  .floo_rsp_t(floo_rsp_t)
) router_1_1 (
  .clk_i,
  .rst_ni,
  .test_enable_i,
  .id_i (ROUTER_1_1_ID),
  .id_route_map_i ('0),
  .floo_req_i (router_1_1_req_in),
  .floo_rsp_o (router_1_1_rsp_out),
  .floo_req_o (router_1_1_req_out),
  .floo_rsp_i (router_1_1_rsp_in)
);


floo_req_t [4:0] router_1_2_req_in;
floo_rsp_t [4:0] router_1_2_rsp_out;
floo_req_t [4:0] router_1_2_req_out;
floo_rsp_t [4:0] router_1_2_rsp_in;

    assign router_1_2_req_in[0] = '0;
    assign router_1_2_req_in[1] = router_2_2_to_router_1_2_req;
    assign router_1_2_req_in[2] = router_1_1_to_router_1_2_req;
    assign router_1_2_req_in[3] = router_0_2_to_router_1_2_req;
    assign router_1_2_req_in[4] = coral_n_ni_to_router_1_2_req;

    assign router_1_2_to_router_2_2_rsp = router_1_2_rsp_out[1];
    assign router_1_2_to_router_1_1_rsp = router_1_2_rsp_out[2];
    assign router_1_2_to_router_0_2_rsp = router_1_2_rsp_out[3];
    assign router_1_2_to_coral_n_ni_rsp = router_1_2_rsp_out[4];

    assign router_1_2_to_router_2_2_req = router_1_2_req_out[1];
    assign router_1_2_to_router_1_1_req = router_1_2_req_out[2];
    assign router_1_2_to_router_0_2_req = router_1_2_req_out[3];
    assign router_1_2_to_coral_n_ni_req = router_1_2_req_out[4];

    assign router_1_2_rsp_in[0] = '0;
    assign router_1_2_rsp_in[1] = router_2_2_to_router_1_2_rsp;
    assign router_1_2_rsp_in[2] = router_1_1_to_router_1_2_rsp;
    assign router_1_2_rsp_in[3] = router_0_2_to_router_1_2_rsp;
    assign router_1_2_rsp_in[4] = coral_n_ni_to_router_1_2_rsp;

  localparam id_t ROUTER_1_2_ID = '{x: 2, y: 2, port_id: 0};

floo_axi_router #(
  .AxiCfg(AxiCfg),
  .RouteAlgo (XYRouting),
  .NumRoutes (5),
  .NumInputs (5),
  .NumOutputs (5),
  .InFifoDepth (2),
  .OutFifoDepth (2),
  .id_t(id_t),
  .hdr_t(hdr_t),
  .floo_req_t(floo_req_t),
  .floo_rsp_t(floo_rsp_t)
) router_1_2 (
  .clk_i,
  .rst_ni,
  .test_enable_i,
  .id_i (ROUTER_1_2_ID),
  .id_route_map_i ('0),
  .floo_req_i (router_1_2_req_in),
  .floo_rsp_o (router_1_2_rsp_out),
  .floo_req_o (router_1_2_req_out),
  .floo_rsp_i (router_1_2_rsp_in)
);


floo_req_t [4:0] router_2_0_req_in;
floo_rsp_t [4:0] router_2_0_rsp_out;
floo_req_t [4:0] router_2_0_req_out;
floo_rsp_t [4:0] router_2_0_rsp_in;

    assign router_2_0_req_in[0] = router_2_1_to_router_2_0_req;
    assign router_2_0_req_in[1] = '0;
    assign router_2_0_req_in[2] = '0;
    assign router_2_0_req_in[3] = router_1_0_to_router_2_0_req;
    assign router_2_0_req_in[4] = coral_e_ni_0_0_to_router_2_0_req;

    assign router_2_0_to_router_2_1_rsp = router_2_0_rsp_out[0];
    assign router_2_0_to_router_1_0_rsp = router_2_0_rsp_out[3];
    assign router_2_0_to_coral_e_ni_0_0_rsp = router_2_0_rsp_out[4];

    assign router_2_0_to_router_2_1_req = router_2_0_req_out[0];
    assign router_2_0_to_router_1_0_req = router_2_0_req_out[3];
    assign router_2_0_to_coral_e_ni_0_0_req = router_2_0_req_out[4];

    assign router_2_0_rsp_in[0] = router_2_1_to_router_2_0_rsp;
    assign router_2_0_rsp_in[1] = '0;
    assign router_2_0_rsp_in[2] = '0;
    assign router_2_0_rsp_in[3] = router_1_0_to_router_2_0_rsp;
    assign router_2_0_rsp_in[4] = coral_e_ni_0_0_to_router_2_0_rsp;

  localparam id_t ROUTER_2_0_ID = '{x: 3, y: 0, port_id: 0};

floo_axi_router #(
  .AxiCfg(AxiCfg),
  .RouteAlgo (XYRouting),
  .NumRoutes (5),
  .NumInputs (5),
  .NumOutputs (5),
  .InFifoDepth (2),
  .OutFifoDepth (2),
  .id_t(id_t),
  .hdr_t(hdr_t),
  .floo_req_t(floo_req_t),
  .floo_rsp_t(floo_rsp_t)
) router_2_0 (
  .clk_i,
  .rst_ni,
  .test_enable_i,
  .id_i (ROUTER_2_0_ID),
  .id_route_map_i ('0),
  .floo_req_i (router_2_0_req_in),
  .floo_rsp_o (router_2_0_rsp_out),
  .floo_req_o (router_2_0_req_out),
  .floo_rsp_i (router_2_0_rsp_in)
);


floo_req_t [4:0] router_2_1_req_in;
floo_rsp_t [4:0] router_2_1_rsp_out;
floo_req_t [4:0] router_2_1_req_out;
floo_rsp_t [4:0] router_2_1_rsp_in;

    assign router_2_1_req_in[0] = router_2_2_to_router_2_1_req;
    assign router_2_1_req_in[1] = mem_ni_to_router_2_1_req;
    assign router_2_1_req_in[2] = router_2_0_to_router_2_1_req;
    assign router_2_1_req_in[3] = router_1_1_to_router_2_1_req;
    assign router_2_1_req_in[4] = coral_e_ni_0_1_to_router_2_1_req;

    assign router_2_1_to_router_2_2_rsp = router_2_1_rsp_out[0];
    assign router_2_1_to_mem_ni_rsp = router_2_1_rsp_out[1];
    assign router_2_1_to_router_2_0_rsp = router_2_1_rsp_out[2];
    assign router_2_1_to_router_1_1_rsp = router_2_1_rsp_out[3];
    assign router_2_1_to_coral_e_ni_0_1_rsp = router_2_1_rsp_out[4];

    assign router_2_1_to_router_2_2_req = router_2_1_req_out[0];
    assign router_2_1_to_mem_ni_req = router_2_1_req_out[1];
    assign router_2_1_to_router_2_0_req = router_2_1_req_out[2];
    assign router_2_1_to_router_1_1_req = router_2_1_req_out[3];
    assign router_2_1_to_coral_e_ni_0_1_req = router_2_1_req_out[4];

    assign router_2_1_rsp_in[0] = router_2_2_to_router_2_1_rsp;
    assign router_2_1_rsp_in[1] = mem_ni_to_router_2_1_rsp;
    assign router_2_1_rsp_in[2] = router_2_0_to_router_2_1_rsp;
    assign router_2_1_rsp_in[3] = router_1_1_to_router_2_1_rsp;
    assign router_2_1_rsp_in[4] = coral_e_ni_0_1_to_router_2_1_rsp;

  localparam id_t ROUTER_2_1_ID = '{x: 3, y: 1, port_id: 0};

floo_axi_router #(
  .AxiCfg(AxiCfg),
  .RouteAlgo (XYRouting),
  .NumRoutes (5),
  .NumInputs (5),
  .NumOutputs (5),
  .InFifoDepth (2),
  .OutFifoDepth (2),
  .id_t(id_t),
  .hdr_t(hdr_t),
  .floo_req_t(floo_req_t),
  .floo_rsp_t(floo_rsp_t)
) router_2_1 (
  .clk_i,
  .rst_ni,
  .test_enable_i,
  .id_i (ROUTER_2_1_ID),
  .id_route_map_i ('0),
  .floo_req_i (router_2_1_req_in),
  .floo_rsp_o (router_2_1_rsp_out),
  .floo_req_o (router_2_1_req_out),
  .floo_rsp_i (router_2_1_rsp_in)
);


floo_req_t [4:0] router_2_2_req_in;
floo_rsp_t [4:0] router_2_2_rsp_out;
floo_req_t [4:0] router_2_2_req_out;
floo_rsp_t [4:0] router_2_2_rsp_in;

    assign router_2_2_req_in[0] = '0;
    assign router_2_2_req_in[1] = '0;
    assign router_2_2_req_in[2] = router_2_1_to_router_2_2_req;
    assign router_2_2_req_in[3] = router_1_2_to_router_2_2_req;
    assign router_2_2_req_in[4] = coral_e_ni_0_2_to_router_2_2_req;

    assign router_2_2_to_router_2_1_rsp = router_2_2_rsp_out[2];
    assign router_2_2_to_router_1_2_rsp = router_2_2_rsp_out[3];
    assign router_2_2_to_coral_e_ni_0_2_rsp = router_2_2_rsp_out[4];

    assign router_2_2_to_router_2_1_req = router_2_2_req_out[2];
    assign router_2_2_to_router_1_2_req = router_2_2_req_out[3];
    assign router_2_2_to_coral_e_ni_0_2_req = router_2_2_req_out[4];

    assign router_2_2_rsp_in[0] = '0;
    assign router_2_2_rsp_in[1] = '0;
    assign router_2_2_rsp_in[2] = router_2_1_to_router_2_2_rsp;
    assign router_2_2_rsp_in[3] = router_1_2_to_router_2_2_rsp;
    assign router_2_2_rsp_in[4] = coral_e_ni_0_2_to_router_2_2_rsp;

  localparam id_t ROUTER_2_2_ID = '{x: 3, y: 2, port_id: 0};

floo_axi_router #(
  .AxiCfg(AxiCfg),
  .RouteAlgo (XYRouting),
  .NumRoutes (5),
  .NumInputs (5),
  .NumOutputs (5),
  .InFifoDepth (2),
  .OutFifoDepth (2),
  .id_t(id_t),
  .hdr_t(hdr_t),
  .floo_req_t(floo_req_t),
  .floo_rsp_t(floo_rsp_t)
) router_2_2 (
  .clk_i,
  .rst_ni,
  .test_enable_i,
  .id_i (ROUTER_2_2_ID),
  .id_route_map_i ('0),
  .floo_req_i (router_2_2_req_in),
  .floo_rsp_o (router_2_2_rsp_out),
  .floo_req_o (router_2_2_req_out),
  .floo_rsp_i (router_2_2_rsp_in)
);



endmodule
