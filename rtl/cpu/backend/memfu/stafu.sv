`include "backend_define.svh"






module stafu (
    input wire clk,
    input wire rst,

    output wire o_stall,
    input wire i_vld,
    input exeInfo_t i_fuInfo,

    store2que_if.m if_sta2que,

    output wire o_has_except,
    output exceptwbInfo_t o_exceptwbInfo
);
    // calculate store addr
    // check memory violation
    genvar i;

    reg s0_vld;
    exeInfo_t s0_fuInfo;

    always_ff @( posedge clk ) begin
        if (rst) begin
            s0_vld;
        end
        else begin
            s0_vld <= i_vld;
            s0_fuInfo <= i_fuInfo;
        end
    end

    wire [`XDEF] s0_vaddr;
    assign s0_vaddr = s0_fuInfo.srcs[0] + s0_fuInfo.srcs[1];

    wire [`WDEF(`XLEN/8)] s0_store_vec;
    wire [`WDEF($clog2(8))] s0_store_size;
    wire store_misaligned;
    assign s0_store_vec =
    (s0_fuInfo.micOp == MicOp_t::sb) ? (8'b0000_0001 << s0_vaddr[2:0]) :
    (s0_fuInfo.micOp == MicOp_t::sh) ? (8'b0000_0011 << s0_vaddr[2:0]) :
    (s0_fuInfo.micOp == MicOp_t::sw) ? (8'b0000_1111 << s0_vaddr[2:0]) :
    8'b1111_1111;

    assign s0_store_size =
    (s0_fuInfo.micOp == MicOp_t::sb) ? 1 :
    (s0_fuInfo.micOp == MicOp_t::sh) ? 2 :
    (s0_fuInfo.micOp == MicOp_t::sw) ? 4 :
    8 ;

    assign store_misaligned = (s0_vaddr[2:0] & (s0_store_size - 1)) != 0;

endmodule
