
`include "core_define.svh"

module alu_scu (
    input wire clk,
    input wire rst,

    output wire o_fu_stall,
    //ctrl info
    input wire i_vld,
    input exeInfo_t i_fuInfo,

    input csr_in_pack_t i_csr_pack,
    input wire i_illegal_access_csr,  // illegal access csr
    input wire [`WDEF(5)] i_zimm,
    input wire i_write_csr,
    input csrIdx_t i_csrIdx,

    // export bypass
    output wire o_willwrite_vld,
    output iprIdx_t o_willwrite_rdIdx,
    output wire [`XDEF] o_willwrite_data,

    // exception wb
    output wire o_has_except,
    output exceptwbInfo_t o_exceptwbInfo,

    //wb, rd_idx will be used to fast bypass
    input wire i_wb_stall,
    output wire o_fu_finished,
    output comwbInfo_t o_comwbInfo,

    syscall_if.m if_syscall,
    output wire o_write_csr,
    output csrIdx_t o_write_csrIdx,
    output wire [`XDEF] o_write_new_csr
);
    reg illegal_csr;

    reg [`WDEF(5)] zimm;
    reg write_csr;  // rs1 != 0
    csrIdx_t saved_csrIdx;
    reg saved_vld;
    exeInfo_t saved_fuInfo;

    always_ff @(posedge clk) begin : blockName
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
                update_instPos(i_fuInfo.seqNum, difftest_def::AT_fu);
            end
        end
    end


    wire [`XDEF] src0 = saved_fuInfo.srcs[0];
    wire [`XDEF] src1 = saved_fuInfo.srcs[1];

    `include "alu.svh.tmp"

    wire [`XDEF] csr_val = src1;
    wire use_zimm = (saved_fuInfo.micOp > MicOp_t::csrrs);
    wire [`XDEF] n_src0 = use_zimm ? {59'd0, zimm} : src0;
    wire [`XDEF] new_csr;
    wire [`XDEF] csr_w = n_src0;
    wire [`XDEF] csr_c = csr_val & (~n_src0);
    wire [`XDEF] csr_s = csr_val | n_src0;

    assign new_csr =
        (saved_fuInfo.micOp == MicOp_t::csrrw) || (saved_fuInfo.micOp == MicOp_t::csrrwi) ? csr_w :
        (saved_fuInfo.micOp == MicOp_t::csrrc) || (saved_fuInfo.micOp == MicOp_t::csrrci) ? csr_c :
        (saved_fuInfo.micOp == MicOp_t::csrrs) || (saved_fuInfo.micOp == MicOp_t::csrrsi) ? csr_s :
        0;

    wire[`XDEF] final_result =
        (saved_fuInfo.issueQueId == `ALUIQ_ID) ? calc_data :
        (saved_fuInfo.issueQueId == `SCUIQ_ID) ? csr_val : 0;

    wire ecall = (saved_fuInfo.issueQueId == `SCUIQ_ID) && (saved_fuInfo.micOp == MicOp_t::ecall);
    wire ebreak = (saved_fuInfo.issueQueId == `SCUIQ_ID) && (saved_fuInfo.micOp == MicOp_t::ebreak);
    // NOTE: mret/sret do not cause except if permission is legal
    wire mret = (saved_fuInfo.issueQueId == `SCUIQ_ID) && (saved_fuInfo.micOp == MicOp_t::mret);
    wire sret = (saved_fuInfo.issueQueId == `SCUIQ_ID) && (saved_fuInfo.micOp == MicOp_t::sret);
    wire illegal_eret = mret ? i_csr_pack.mode < `MODE_M : sret ? i_csr_pack.mode < `MODE_S : 0;

    wire sysexcept = (saved_fuInfo.issueQueId == `SCUIQ_ID) && (ecall || ebreak);
    rv_trap_t::exception syscall_except;
    assign syscall_except =
        ecall ? (rv_trap_t::ucall + i_csr_pack.mode) :
        ebreak ? rv_trap_t::breakpoint :
        rv_trap_t::breakpoint;

    wire instIllegal = illegal_csr || illegal_eret;

    reg _has_except;
    exceptwbInfo_t exceptwbInfo;

    reg fu_finished;
    comwbInfo_t comwbInfo;
    reg _write_csr;
    csrIdx_t _write_csrIdx;
    reg [`XDEF] _new_csr;
    always_ff @(posedge clk) begin
        if (rst) begin
            _has_except <= 0;
            _write_csr <= 0;
            fu_finished <= 0;
        end
        else if (!i_wb_stall) begin
            fu_finished <= saved_vld;
            comwbInfo.rob_idx <= saved_fuInfo.robIdx;
            comwbInfo.irob_idx <= saved_fuInfo.irobIdx;
            comwbInfo.use_imm <= saved_fuInfo.useImm;
            comwbInfo.rd_wen <= saved_fuInfo.rdwen;
            comwbInfo.iprd_idx <= saved_fuInfo.iprd;
            comwbInfo.result <= final_result;

            _has_except <= saved_vld && (instIllegal || sysexcept);
            exceptwbInfo <= '{
                default: 0,
                rob_idx : saved_fuInfo.robIdx,
                except_type : instIllegal ? rv_trap_t::instIllegal : sysexcept ? syscall_except : 0
            };

            _write_csr <= saved_vld && write_csr;
            _write_csrIdx <= saved_csrIdx;
            _new_csr <= new_csr;
            if (saved_vld) begin
                assert (saved_fuInfo.issueQueId == `ALUIQ_ID || saved_fuInfo.issueQueId == `SCUIQ_ID);
                update_instPos(saved_fuInfo.seqNum, difftest_def::AT_wb);
            end
        end
    end

    assign o_willwrite_vld = saved_vld && saved_fuInfo.rdwen;
    assign o_willwrite_rdIdx = saved_fuInfo.iprd;
    assign o_willwrite_data = calc_data;

    assign o_fu_stall = i_wb_stall;
    assign o_fu_finished = fu_finished;
    assign o_comwbInfo = comwbInfo;

    assign o_has_except = _has_except;
    assign o_exceptwbInfo = exceptwbInfo;

    assign o_write_csr = _write_csr;
    assign o_write_csrIdx = _write_csrIdx;
    assign o_write_new_csr = _new_csr;


    // system call/ret
    reg _mret;
    reg _sret;
    reg [`XDEF] eret_pc;


    always_ff @(posedge clk) begin
        if (rst) begin
            _mret <= 0;
            _sret <= 0;
        end
        else if (saved_vld) begin
            _mret <= saved_vld && (saved_fuInfo.issueQueId == `SCUIQ_ID) && (saved_fuInfo.micOp == MicOp_t::mret);
            _sret <= saved_vld && (saved_fuInfo.issueQueId == `SCUIQ_ID) && (saved_fuInfo.micOp == MicOp_t::sret);
            eret_pc <= i_csr_pack.epc;
        end
        else begin
            _mret <= 0;
            _sret <= 0;
        end
    end

    assign if_syscall.rob_idx = comwbInfo.rob_idx;
    assign if_syscall.mret = _mret;
    assign if_syscall.sret = _sret;
    assign if_syscall.npc = eret_pc;

endmodule
