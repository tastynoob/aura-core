`include "frontend_define.svh"


module preDecode (
    input wire [`IDEF] i_inst,
    input wire [`XDEF] i_pc,
    output preDecInfo_t o_info
);
    wire isRVC = (i_inst[1:0] != 2'b11);

    wire inst_JALR = (i_inst ==? 32'b?????????????????000?????1100111);
    wire inst_JAL = (i_inst ==? 32'b?????????????????????????1101111);
    wire inst_BEQ = (i_inst ==? 32'b?????????????????000?????1100011);
    wire inst_BGE = (i_inst ==? 32'b?????????????????101?????1100011);
    wire inst_BGEU = (i_inst ==? 32'b?????????????????111?????1100011);
    wire inst_BLT = (i_inst ==? 32'b?????????????????100?????1100011);
    wire inst_BLTU = (i_inst ==? 32'b?????????????????110?????1100011);
    wire inst_BNE = (i_inst ==? 32'b?????????????????001?????1100011);
    wire [19:0] inst_i_type_imm = {{8{i_inst[31]}}, i_inst[31:20]};  // jalr
    wire [19:0] inst_j_type_imm = {i_inst[19:12], i_inst[20], i_inst[30:21], 1'b0};  // jal
    wire [19:0] inst_b_type_imm = {{8{i_inst[31]}}, i_inst[7], i_inst[30:25], i_inst[11:8], 1'b0};  // branch

    wire [`XDEF] condTarget = i_pc + {{44{inst_b_type_imm[19]}}, inst_b_type_imm};
    wire [`XDEF] directTarget = i_pc + {{44{inst_j_type_imm[19]}}, inst_j_type_imm};
    wire [`XDEF] indirectTarget = i_pc + {{44{inst_i_type_imm[19]}}, inst_i_type_imm};  // just predicted

    wire isDirect = inst_JAL;
    wire isIndirect = inst_JALR;
    wire isCond = (inst_BEQ || inst_BGE || inst_BGEU || inst_BLT || inst_BLTU || inst_BNE);

    // condBranch's probability of jumping backward is large than jumping forward
    wire condBr_jump_back = isCond && (inst_b_type_imm[19]);

    wire [`XDEF] target = isDirect ? directTarget : isIndirect ? indirectTarget : condTarget;

    wire [`XDEF] fallthru = i_pc + (isRVC ? 2 : 4);

    wire[`XDEF] simplePredNPC =
                isDirect ? directTarget :
                isIndirect ? indirectTarget :
                condBr_jump_back ? condTarget :// a simple predict
    fallthru;

    assign o_info = '{
            fallthru : fallthru,
            isCond : isCond,
            isDirect : isDirect,
            isIndirect : isIndirect,
            isBr : (isCond || isDirect || isIndirect),
            target : target,
            simplePredNPC : simplePredNPC
        };


endmodule


