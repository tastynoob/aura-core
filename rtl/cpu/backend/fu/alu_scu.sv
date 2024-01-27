
`include "core_define.svh"

module alu_scu (
    input wire clk,
    input wire rst,

    output wire o_fu_stall,
    //ctrl info
    input wire i_vld,
    input fuInfo_t i_fuInfo,

    input wire i_illegal_access_csr,// illegal access csr
    input wire[`WDEF(5)] i_zimm,
    input wire i_write_csr,
    input csrIdx_t i_csrIdx,

    // export bypass
    output wire o_willwrite_vld,
    output iprIdx_t o_willwrite_rdIdx,
    output wire[`XDEF] o_willwrite_data,

    // exception wb
    output wire o_has_except,
    output exceptwbInfo_t o_exceptwbInfo,

    //wb, rd_idx will be used to fast bypass
    input wire i_wb_stall,
    output wire o_fu_finished,
    output comwbInfo_t o_comwbInfo,
    output wire o_write_csr,
    output csrIdx_t o_write_csrIdx,
    output wire[`XDEF] o_write_new_csr
);
    reg illegal_csr;

    reg[`WDEF(5)] zimm;
    reg write_csr; // rs1 != 0
    csrIdx_t saved_csrIdx;
    reg saved_vld;
    fuInfo_t saved_fuInfo;

    always_ff @( posedge clk ) begin : blockName
        if (rst) begin
            illegal_csr <= 0;
            write_csr <= 0;
            saved_vld <= 0;
        end
        else if (!i_wb_stall) begin
            illegal_csr <= i_illegal_access_csr;

            zimm <= i_zimm;
            write_csr <= i_write_csr && !i_illegal_access_csr;
            saved_csrIdx <= i_csrIdx;

            saved_vld <= i_vld;
            saved_fuInfo <= i_fuInfo;
            if (i_vld) begin
                update_instPos(i_fuInfo.instmeta, difftest_def::AT_fu);
            end
        end
    end


    wire[`XDEF] src0 = saved_fuInfo.srcs[0];
    wire[`XDEF] src1 = saved_fuInfo.srcs[1];

    `include "alu.svh.tmp"

    wire[`XDEF] csr_val = src1;
    wire use_zimm = (saved_fuInfo.micOp > MicOp_t::csrrs);
    wire[`XDEF] n_src0 = use_zimm ? {59'd0, zimm} : src0;
    wire[`XDEF] new_csr;
    wire[`XDEF] csr_w = n_src0;
    wire[`XDEF] csr_c = csr_val & (~n_src0);
    wire[`XDEF] csr_s = csr_val | n_src0;

    assign new_csr =
        (saved_fuInfo.micOp == MicOp_t::csrrw) || (saved_fuInfo.micOp == MicOp_t::csrrwi) ? csr_w :
        (saved_fuInfo.micOp == MicOp_t::csrrc) || (saved_fuInfo.micOp == MicOp_t::csrrci) ? csr_c :
        (saved_fuInfo.micOp == MicOp_t::csrrs) || (saved_fuInfo.micOp == MicOp_t::csrrsi) ? csr_s :
        0;

    wire[`XDEF] final_result =
        saved_fuInfo.issueQue_id == `ALUIQ_ID ? calc_data :
        saved_fuInfo.issueQue_id == `SCUIQ_ID ? csr_val : 0;

    reg _has_except;
    exceptwbInfo_t exceptwbInfo;

    reg fu_finished;
    comwbInfo_t comwbInfo;
    reg _write_csr;
    csrIdx_t _write_csrIdx;
    reg[`XDEF] _new_csr;
    always_ff @(posedge clk) begin
        if (rst) begin
            _has_except <= 0;
            _write_csr <= 0;
            fu_finished <= 0;
        end
        else if (!i_wb_stall) begin
            fu_finished <= saved_vld;
            comwbInfo.rob_idx <= saved_fuInfo.rob_idx;
            comwbInfo.irob_idx <= saved_fuInfo.irob_idx;
            comwbInfo.use_imm <= saved_fuInfo.use_imm;
            comwbInfo.rd_wen <= saved_fuInfo.rd_wen;
            comwbInfo.iprd_idx <= saved_fuInfo.iprd_idx;
            comwbInfo.result <= final_result;

            _has_except <= saved_vld && illegal_csr;
            exceptwbInfo <= '{
                rob_idx : saved_fuInfo.rob_idx,
                except_type : illegal_csr ? rv_trap_t::instIllegal : 0
            };

            _write_csr <= saved_vld && write_csr;
            _write_csrIdx <= saved_csrIdx;
            _new_csr <= new_csr;
            if (saved_vld) begin
                assert(saved_fuInfo.issueQue_id == `ALUIQ_ID || saved_fuInfo.issueQue_id == `SCUIQ_ID);
                update_instPos(saved_fuInfo.instmeta, difftest_def::AT_wb);
            end
        end
    end

    assign o_willwrite_vld = saved_vld && saved_fuInfo.rd_wen;
    assign o_willwrite_rdIdx = saved_fuInfo.iprd_idx;
    assign o_willwrite_data = calc_data;

    assign o_fu_stall = i_wb_stall;
    assign o_fu_finished = fu_finished;
    assign o_comwbInfo = comwbInfo;

    assign o_has_except = _has_except;
    assign o_exceptwbInfo = exceptwbInfo;

    assign o_write_csr = _write_csr;
    assign o_write_csrIdx = _write_csrIdx;
    assign o_write_new_csr = _new_csr;


endmodule
