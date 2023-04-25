
`include "fu_define.svh"



module alu #(
    parameter int BYPASS_WID = 4
)(
    input wire clk,
    input wire rst,
    //ctrl info
    input robIdx_t i_robIdx,
    input wire[`XDEF] i_bypass_datas[BYPASS_WID],
    input wire[`WDEF($clog2(BYPASS_WID)-1)] i_bypass_idx0,
    input wire i_need_bypass0,
    input wire i_need_bypass1,
    input wire[`WDEF($clog2(BYPASS_WID)-1)] i_bypass_idx1,
    input wire[`XDEF] i_src0,
    input wire[`XDEF] i_src1,

    output robIdx_t o_robIdx,
    output iprIdx_t o_iprd_idx,
    output wire[`XDEF] o_dst
);

    wire[`XDEF] src0 = i_need_bypass0 ? i_wb_datas[i_bypass_idx0] : i_src0;
    wire[`XDEF] src1 = i_need_bypass1 ? i_wb_datas[i_bypass_idx1] : i_src1;


    wire[`XDEF] add = src0 + src1;
    wire[`XDEF] sub = src0 - src1;








endmodule
