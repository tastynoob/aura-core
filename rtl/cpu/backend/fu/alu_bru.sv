
`include "core_define.svh"

module alu_bru (
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
    output comwbInfo_t o_comwbInfo,
    output wire o_branchwb_vld,
    output branchwbInfo_t o_branchwbInfo
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
        end
    end


    wire[`XDEF] src0 = saved_fuInfo.srcs[0];
    wire[`XDEF] src1 = saved_fuInfo.srcs[1];

/****************************************************************************************************/
// alu
/****************************************************************************************************/
    wire[5:0] shifter = src1[5:0];

    wire[`XDEF] lui = {{32{1'b1}},src1[19:0],12'd0};
    wire[`XDEF] add = src0 + src1;
    wire[`XDEF] sub = src0 - src1;
    wire[`XDEF] addw = {{32{add[31]}},add[31:0]};
    wire[`XDEF] subw = {{32{sub[31]}},sub[31:0]};
    wire[`XDEF] sll = (src0 << shifter);
    wire[`XDEF] srl = (src0 >> shifter);
    wire[`XDEF] sra = (({64{src0[63]}} << (7'd64 - {1'b0, shifter})) | (src0 >> shifter));
    wire[`XDEF] sllw = {{32{sll[31]}},sll[31:0]};
    wire[`XDEF] srlw = {{32{srl[31]}},srl[31:0]};
    wire[`XDEF] sraw = {{32{sra[31]}},sra[31:0]};

    wire[`XDEF] _xor = src0 ^ src1;
    wire[`XDEF] _or = src0 | src1;
    wire[`XDEF] _and = src0 & src1;
    // signed
    // src0 < src1 (src0 - src1 < 0)
    wire[`XDEF] slt = {63'd0,sub[63]};
    // unsigned
    // src0 > src1 : fasle : src0 - src1 > 0
    wire[`XDEF] sltu = src0 < src1;


    wire[`XDEF] calc_data =
    (saved_fuInfo.micOp == MicOp_t::lui) ? lui :
    (saved_fuInfo.micOp == MicOp_t::add) ? add :
    (saved_fuInfo.micOp == MicOp_t::sub) ? sub :
    (saved_fuInfo.micOp == MicOp_t::addw) ? addw :
    (saved_fuInfo.micOp == MicOp_t::subw) ? subw :
    (saved_fuInfo.micOp == MicOp_t::sll) ? sll :
    (saved_fuInfo.micOp == MicOp_t::srl) ? srl :
    (saved_fuInfo.micOp == MicOp_t::sra) ? sra :
    (saved_fuInfo.micOp == MicOp_t::sllw) ? sllw :
    (saved_fuInfo.micOp == MicOp_t::srlw) ? srlw :
    (saved_fuInfo.micOp == MicOp_t::sraw) ? sraw :
    (saved_fuInfo.micOp == MicOp_t::_xor) ? _xor :
    (saved_fuInfo.micOp == MicOp_t::_or) ? _or :
    (saved_fuInfo.micOp == MicOp_t::_and) ? _and :
    (saved_fuInfo.micOp == MicOp_t::slt) ? slt :
    (saved_fuInfo.micOp == MicOp_t::sltu) ? sltu :
    0;

/****************************************************************************************************/
// bru
/****************************************************************************************************/

    wire[`XDEF] pc = saved_fuInfo.pc;
    wire[`XDEF] pred_npc = saved_fuInfo.npc;
    wire[`XDEF] fallthru = saved_fuInfo.pc + 4;
    wire[`XDEF] imm20 = {{44{saved_fuInfo.imm20[19]}}, saved_fuInfo.imm20};

    wire[`XDEF] jal_target = pc + imm20;
    wire[`XDEF] jalr_target = src0 + imm20;
    wire[`XDEF] br_target = pc + imm20;

    wire beq_taken = src0 == src1;
    wire bne_taken = !beq_taken;
    wire blt_taken = slt;
    wire bge_taken = !blt_taken;
    wire bltu_taken = sltu;
    wire bgeu_taken = !bltu_taken;

    wire taken =
    (saved_fuInfo.micOp == MicOp_t::jal) ? 1 :
    (saved_fuInfo.micOp == MicOp_t::jalr) ? 1 :
    (saved_fuInfo.micOp == MicOp_t::beq) ? beq_taken :
    (saved_fuInfo.micOp == MicOp_t::bne) ? bne_taken :
    (saved_fuInfo.micOp == MicOp_t::blt) ? blt_taken :
    (saved_fuInfo.micOp == MicOp_t::bge) ? bge_taken :
    (saved_fuInfo.micOp == MicOp_t::bltu) ? bltu_taken :
    (saved_fuInfo.micOp == MicOp_t::bgeu) ? bgeu_taken :
    0;

    wire[`XDEF] target =
    (saved_fuInfo.micOp == MicOp_t::jal) ? jal_target :
    (saved_fuInfo.micOp == MicOp_t::jalr) ? jalr_target :
    br_target;

    wire[`XDEF] npc =
    taken ? target : fallthru;

    wire mispred = npc != pred_npc;
    //TODO: remove it
    BranchType::_ branch_type;
    assign branch_type =
    (saved_fuInfo.micOp == MicOp_t::jalr) && (saved_fuInfo.iprd_idx == 1) ? BranchType::isCall :
    (saved_fuInfo.micOp == MicOp_t::jalr) && (saved_fuInfo.iprd_idx == 0) ? BranchType::isRet : //FIXME: iprs[0] should is 1
    (saved_fuInfo.micOp == MicOp_t::jalr) ? BranchType::isIndirect :
    (saved_fuInfo.micOp == MicOp_t::jal) ? BranchType::isDirect :
    BranchType::isCond;

    reg fu_finished;
    comwbInfo_t comwbInfo;
    reg branchwb_vld;
    branchwbInfo_t branchwb_info;
    always_ff @(posedge clk) begin
        if (rst) begin
            fu_finished <= 0;
            branchwb_vld <= 0;
        end
        else if (!i_wb_stall) begin
            fu_finished <= saved_vld;
            comwbInfo.rob_idx <= saved_fuInfo.rob_idx;
            comwbInfo.irob_idx <= saved_fuInfo.irob_idx;
            comwbInfo.use_imm <= saved_fuInfo.use_imm;
            comwbInfo.rd_wen <= saved_fuInfo.rd_wen;
            comwbInfo.iprd_idx <= saved_fuInfo.iprd_idx;
            comwbInfo.result <= (saved_fuInfo.issueQue_id == `BRUIQ_ID) ? fallthru : calc_data;

            // jal must be not mispred
            assert(saved_vld && (saved_fuInfo.issueQue_id == `BRUIQ_ID) && mispred ? (saved_fuInfo.micOp != MicOp_t::jal) : 1);
            // only writeback when mispred
            branchwb_vld <= saved_vld && (saved_fuInfo.issueQue_id == `BRUIQ_ID) && mispred;
            branchwb_info <= '{
                branch_type : branch_type,
                rob_idx : saved_fuInfo.rob_idx,
                ftq_idx : saved_fuInfo.ftq_idx,
                has_mispred : mispred,
                branch_taken : taken,
                //FIXME: fallthruAddr should always point to branch_pc + 4/2
                fallthruOffset : saved_fuInfo.ftqOffset + 4,
                target_pc : target,
                branch_npc : npc
            };
        end
    end

    assign o_willwrite_vld = saved_vld && saved_fuInfo.rd_wen;
    assign o_willwrite_rdIdx = saved_fuInfo.iprd_idx;
    assign o_willwrite_data = calc_data;

    assign o_fu_stall = i_wb_stall;
    assign o_fu_finished = fu_finished;
    assign o_comwbInfo = comwbInfo;
    assign o_branchwb_vld = branchwb_vld;
    assign o_branchwbInfo = branchwb_info;



endmodule
