
`include "core_define.svh"

module alu (
    input wire clk,
    input wire rst,

    output wire o_fu_stall,
    //ctrl info
    input wire i_vld,
    input fuInfo_t i_fuInfo,

    // export bypass
    output wire o_willwrite_vld,
    output iprIdx_t o_willwrite_rdIdx,
    output wire[`XDEF] o_willwrite_data,

    //wb, rd_idx will be used to fast bypass
    input wire i_wb_stall,
    output wire o_fu_finished,
    output comwbInfo_t o_comwbInfo
);

    reg saved_vld;
    fuInfo_t saved_fuInfo;

    always_ff @( posedge clk ) begin : blockName
        if (rst==true) begin
            saved_vld <= 0;
        end
        else if (!i_wb_stall) begin
            saved_vld <= i_vld;
            saved_fuInfo <= i_fuInfo;
            if (i_vld) begin
                update_instPos(i_fuInfo.instmeta, difftest_def::AT_fu);
            end
        end
    end


    wire[`XDEF] src0 = saved_fuInfo.srcs[0];
    wire[`XDEF] src1 = saved_fuInfo.srcs[1];

    `include "alu_tmp.svh"

    reg fu_finished;
    comwbInfo_t comwbInfo;
    always_ff @(posedge clk) begin
        if (rst) begin
            fu_finished <= 0;
        end
        else if (!i_wb_stall) begin
            fu_finished <= saved_vld;
            comwbInfo.rob_idx <= saved_fuInfo.rob_idx;
            comwbInfo.irob_idx <= saved_fuInfo.irob_idx;
            comwbInfo.use_imm <= saved_fuInfo.use_imm;
            comwbInfo.rd_wen <= saved_fuInfo.rd_wen;
            comwbInfo.iprd_idx <= saved_fuInfo.iprd_idx;
            comwbInfo.result <= calc_data;
        end
    end

    assign o_willwrite_vld = saved_vld && saved_fuInfo.rd_wen;
    assign o_willwrite_rdIdx = saved_fuInfo.iprd_idx;
    assign o_willwrite_data = calc_data;

    assign o_fu_stall = i_wb_stall;
    assign o_fu_finished = fu_finished;
    assign o_comwbInfo = comwbInfo;



endmodule
