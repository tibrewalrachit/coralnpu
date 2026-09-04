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

// AXI types for the Snitch cluster hub tile (snitch_floo_hub.sv).
//
// The Snitch-side widths must match the snitch_cluster generated
// configuration (hw/generated/snitch_cluster_wrapper_pkg.sv of the
// cluster build); the defaults below match the upstream default config:
// 48-bit addresses, 64-bit narrow / 512-bit wide data, and the ID/user
// widths listed per typedef. The NoC side is the Coral mesh protocol:
// 32-bit address, 128-bit data, 6-bit ID, 1-bit user.

`include "axi/typedef.svh"

package snitch_floo_hub_pkg;

  // Snitch cluster interface widths (keep in sync with the cluster config).
  localparam int unsigned SnAddrWidth       = 48;
  localparam int unsigned SnNarrowDataWidth = 64;
  localparam int unsigned SnWideDataWidth   = 512;
  localparam int unsigned SnNarrowIdWidthIn  = 2;  // cluster narrow_in
  localparam int unsigned SnNarrowIdWidthOut = 4;  // cluster narrow_out
  localparam int unsigned SnWideIdWidthIn    = 1;  // cluster wide_in
  localparam int unsigned SnWideIdWidthOut   = 3;  // cluster wide_out
  localparam int unsigned SnNarrowUserWidth  = 5;  // atomic_id
  localparam int unsigned SnWideUserWidth    = 1;

  // NoC protocol (Coral mesh axi_in/axi_out).
  localparam int unsigned NocAddrWidth = 32;
  localparam int unsigned NocDataWidth = 128;
  localparam int unsigned NocIdWidth   = 6;
  localparam int unsigned NocUserWidth = 1;

  // The two cluster manager ports are muxed onto one NoC manager port;
  // the mux prepends one ID bit, so its subordinate-side ID width is 5.
  localparam int unsigned HubMuxIdWidth = NocIdWidth - 1;

  typedef logic [SnAddrWidth-1:0]         sn_addr_t;
  typedef logic [SnNarrowDataWidth-1:0]   sn_narrow_data_t;
  typedef logic [SnNarrowDataWidth/8-1:0] sn_narrow_strb_t;
  typedef logic [SnWideDataWidth-1:0]     sn_wide_data_t;
  typedef logic [SnWideDataWidth/8-1:0]   sn_wide_strb_t;
  typedef logic [SnNarrowIdWidthIn-1:0]   sn_narrow_in_id_t;
  typedef logic [SnNarrowIdWidthOut-1:0]  sn_narrow_out_id_t;
  typedef logic [SnWideIdWidthIn-1:0]     sn_wide_in_id_t;
  typedef logic [SnWideIdWidthOut-1:0]    sn_wide_out_id_t;
  typedef logic [SnNarrowUserWidth-1:0]   sn_narrow_user_t;
  typedef logic [SnWideUserWidth-1:0]     sn_wide_user_t;

  typedef logic [NocAddrWidth-1:0]        noc_addr_t;
  typedef logic [NocDataWidth-1:0]        noc_data_t;
  typedef logic [NocDataWidth/8-1:0]      noc_strb_t;
  typedef logic [NocIdWidth-1:0]          noc_id_t;
  typedef logic [NocUserWidth-1:0]        noc_user_t;
  typedef logic [HubMuxIdWidth-1:0]       hub_id_t;

  // Cluster-facing types (structurally identical to the generated
  // snitch_cluster_wrapper_pkg AXI types).
  `AXI_TYPEDEF_ALL_CT(sn_narrow_in, sn_narrow_in_req_t, sn_narrow_in_rsp_t,
                      sn_addr_t, sn_narrow_in_id_t, sn_narrow_data_t,
                      sn_narrow_strb_t, sn_narrow_user_t)
  `AXI_TYPEDEF_ALL_CT(sn_narrow_out, sn_narrow_out_req_t, sn_narrow_out_rsp_t,
                      sn_addr_t, sn_narrow_out_id_t, sn_narrow_data_t,
                      sn_narrow_strb_t, sn_narrow_user_t)
  `AXI_TYPEDEF_ALL_CT(sn_wide_in, sn_wide_in_req_t, sn_wide_in_rsp_t,
                      sn_addr_t, sn_wide_in_id_t, sn_wide_data_t,
                      sn_wide_strb_t, sn_wide_user_t)
  `AXI_TYPEDEF_ALL_CT(sn_wide_out, sn_wide_out_req_t, sn_wide_out_rsp_t,
                      sn_addr_t, sn_wide_out_id_t, sn_wide_data_t,
                      sn_wide_strb_t, sn_wide_user_t)

  // Manager path: cluster ports width-converted to 128-bit data, still in
  // the cluster's address/ID/user domain.
  `AXI_TYPEDEF_ALL_CT(n128, n128_req_t, n128_rsp_t,
                      sn_addr_t, sn_narrow_out_id_t, noc_data_t,
                      noc_strb_t, sn_narrow_user_t)
  `AXI_TYPEDEF_ALL_CT(w128, w128_req_t, w128_rsp_t,
                      sn_addr_t, sn_wide_out_id_t, noc_data_t,
                      noc_strb_t, sn_wide_user_t)

  // Mux subordinate ports (NoC address/user domain, 5-bit IDs).
  `AXI_TYPEDEF_ALL_CT(hub, hub_req_t, hub_rsp_t,
                      noc_addr_t, hub_id_t, noc_data_t,
                      noc_strb_t, noc_user_t)

  // NoC-facing types (structurally identical to the FlooGen axi_in/axi_out).
  `AXI_TYPEDEF_ALL_CT(noc, noc_req_t, noc_rsp_t,
                      noc_addr_t, noc_id_t, noc_data_t,
                      noc_strb_t, noc_user_t)

  // Subordinate path: NoC request lifted into the cluster address/user
  // domain, then width- and ID-converted down to the cluster narrow_in.
  `AXI_TYPEDEF_ALL_CT(s128, s128_req_t, s128_rsp_t,
                      sn_addr_t, noc_id_t, noc_data_t,
                      noc_strb_t, sn_narrow_user_t)
  `AXI_TYPEDEF_ALL_CT(s64, s64_req_t, s64_rsp_t,
                      sn_addr_t, noc_id_t, sn_narrow_data_t,
                      sn_narrow_strb_t, sn_narrow_user_t)

endpackage
