`include "backend_define.svh"





// NOTE:
// if ld0 has dep on st0
// ld0 can't execute parallel with st0
module stdfu (
    input wire clk,
    input wire rst,

    input wire i_vld,
    input exeInfo_t i_fuInfo,

    store2que_if.m if_std2que
);

    reg s0_vld;
    exeInfo_t s0_fuInfo;

    always_ff @(posedge clk) begin
        if (rst) begin
            s0_vld <= 0;
        end
        else begin
            s0_vld <= i_vld;
            s0_fuInfo <= i_fuInfo;
        end
    end


    assign if_std2que.vld = s0_vld;
    assign if_std2que.sqIdx = s0_fuInfo.sqIdx;
    assign if_std2que.data = s0_fuInfo.srcs[0];
endmodule
