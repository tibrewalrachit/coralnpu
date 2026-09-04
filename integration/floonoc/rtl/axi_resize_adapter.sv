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

// Field-wise adapter between two PULP-style AXI struct type sets that share
// data width but may differ in address, ID, or user width. Each field is
// size-cast (zero-extended or truncated); handshakes pass through
// combinationally. Used by snitch_floo_hub.sv to move between the Snitch
// cluster's 48-bit-address / wide-user domain and the 32-bit NoC domain.
//
// Truncation caveats (fine in this design, checked by the address map):
//  - slv->mst address truncation assumes the manager only emits addresses
//    that fit the master-side address width;
//  - ID widths must only shrink where the wider side carries zero-extended
//    values of the narrower side (as after padding, or on response paths).

module axi_resize_adapter #(
  parameter type slv_req_t = logic,
  parameter type slv_rsp_t = logic,
  parameter type mst_req_t = logic,
  parameter type mst_rsp_t = logic
) (
  input  slv_req_t slv_req_i,
  output slv_rsp_t slv_rsp_o,
  output mst_req_t mst_req_o,
  input  mst_rsp_t mst_rsp_i
);

  always_comb begin
    mst_req_o = '0;

    mst_req_o.aw_valid  = slv_req_i.aw_valid;
    mst_req_o.aw.id     = $bits(mst_req_o.aw.id)'(slv_req_i.aw.id);
    mst_req_o.aw.addr   = $bits(mst_req_o.aw.addr)'(slv_req_i.aw.addr);
    mst_req_o.aw.len    = slv_req_i.aw.len;
    mst_req_o.aw.size   = slv_req_i.aw.size;
    mst_req_o.aw.burst  = slv_req_i.aw.burst;
    mst_req_o.aw.lock   = slv_req_i.aw.lock;
    mst_req_o.aw.cache  = slv_req_i.aw.cache;
    mst_req_o.aw.prot   = slv_req_i.aw.prot;
    mst_req_o.aw.qos    = slv_req_i.aw.qos;
    mst_req_o.aw.region = slv_req_i.aw.region;
    mst_req_o.aw.atop   = slv_req_i.aw.atop;
    mst_req_o.aw.user   = $bits(mst_req_o.aw.user)'(slv_req_i.aw.user);

    mst_req_o.w_valid   = slv_req_i.w_valid;
    mst_req_o.w.data    = slv_req_i.w.data;
    mst_req_o.w.strb    = slv_req_i.w.strb;
    mst_req_o.w.last    = slv_req_i.w.last;
    mst_req_o.w.user    = $bits(mst_req_o.w.user)'(slv_req_i.w.user);

    mst_req_o.b_ready   = slv_req_i.b_ready;

    mst_req_o.ar_valid  = slv_req_i.ar_valid;
    mst_req_o.ar.id     = $bits(mst_req_o.ar.id)'(slv_req_i.ar.id);
    mst_req_o.ar.addr   = $bits(mst_req_o.ar.addr)'(slv_req_i.ar.addr);
    mst_req_o.ar.len    = slv_req_i.ar.len;
    mst_req_o.ar.size   = slv_req_i.ar.size;
    mst_req_o.ar.burst  = slv_req_i.ar.burst;
    mst_req_o.ar.lock   = slv_req_i.ar.lock;
    mst_req_o.ar.cache  = slv_req_i.ar.cache;
    mst_req_o.ar.prot   = slv_req_i.ar.prot;
    mst_req_o.ar.qos    = slv_req_i.ar.qos;
    mst_req_o.ar.region = slv_req_i.ar.region;
    mst_req_o.ar.user   = $bits(mst_req_o.ar.user)'(slv_req_i.ar.user);

    mst_req_o.r_ready   = slv_req_i.r_ready;
  end

  always_comb begin
    slv_rsp_o = '0;

    slv_rsp_o.aw_ready = mst_rsp_i.aw_ready;
    slv_rsp_o.w_ready  = mst_rsp_i.w_ready;
    slv_rsp_o.ar_ready = mst_rsp_i.ar_ready;

    slv_rsp_o.b_valid  = mst_rsp_i.b_valid;
    slv_rsp_o.b.id     = $bits(slv_rsp_o.b.id)'(mst_rsp_i.b.id);
    slv_rsp_o.b.resp   = mst_rsp_i.b.resp;
    slv_rsp_o.b.user   = $bits(slv_rsp_o.b.user)'(mst_rsp_i.b.user);

    slv_rsp_o.r_valid  = mst_rsp_i.r_valid;
    slv_rsp_o.r.id     = $bits(slv_rsp_o.r.id)'(mst_rsp_i.r.id);
    slv_rsp_o.r.data   = mst_rsp_i.r.data;
    slv_rsp_o.r.resp   = mst_rsp_i.r.resp;
    slv_rsp_o.r.last   = mst_rsp_i.r.last;
    slv_rsp_o.r.user   = $bits(slv_rsp_o.r.user)'(mst_rsp_i.r.user);
  end

endmodule
