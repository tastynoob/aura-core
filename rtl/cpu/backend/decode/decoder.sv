`include "core_define.svh"


//对于branch指令
//需要计算:rs1比较人数,优先以rs1与rs2的比较计算
//pc + imm

//not used rdIdx must set to zero

//lui: rd = x0 + imm
//auipc : rd = pc + imm
//jal,jalr : rd = pc
//mark the (mv x1,x1)-like as nop
//TODO: finish decode
module decoder (
    input wire[`IDEF] i_inst,
    input wire[`XDEF] i_inst_pc,
    input wire[`XDEF] i_inst_npc,

    output wire o_unknow_inst,
    //decinfo output
    output decInfo_t o_decinfo
);
    wire[`IDEF] inst = i_inst;
    wire inst_ADD = (inst == 32'b0000000??????????000?????0110011);
    wire inst_ADDI = (inst == 32'b?????????????????000?????0010011);
    wire inst_ADDIW = (inst == 32'b?????????????????000?????0011011);
    wire inst_ADDW = (inst == 32'b0000000??????????000?????0111011);
    wire inst_AMOADD_D = (inst == 32'b00000????????????011?????0101111);
    wire inst_AMOADD_W = (inst == 32'b00000????????????010?????0101111);
    wire inst_AMOAND_D = (inst == 32'b01100????????????011?????0101111);
    wire inst_AMOAND_W = (inst == 32'b01100????????????010?????0101111);
    wire inst_AMOMAX_D = (inst == 32'b10100????????????011?????0101111);
    wire inst_AMOMAX_W = (inst == 32'b10100????????????010?????0101111);
    wire inst_AMOMAXU_D = (inst == 32'b11100????????????011?????0101111);
    wire inst_AMOMAXU_W = (inst == 32'b11100????????????010?????0101111);
    wire inst_AMOMIN_D = (inst == 32'b10000????????????011?????0101111);
    wire inst_AMOMIN_W = (inst == 32'b10000????????????010?????0101111);
    wire inst_AMOMINU_D = (inst == 32'b11000????????????011?????0101111);
    wire inst_AMOMINU_W = (inst == 32'b11000????????????010?????0101111);
    wire inst_AMOOR_D = (inst == 32'b01000????????????011?????0101111);
    wire inst_AMOOR_W = (inst == 32'b01000????????????010?????0101111);
    wire inst_AMOSWAP_D = (inst == 32'b00001????????????011?????0101111);
    wire inst_AMOSWAP_W = (inst == 32'b00001????????????010?????0101111);
    wire inst_AMOXOR_D = (inst == 32'b00100????????????011?????0101111);
    wire inst_AMOXOR_W = (inst == 32'b00100????????????010?????0101111);
    wire inst_AND = (inst == 32'b0000000??????????111?????0110011);
    wire inst_ANDI = (inst == 32'b?????????????????111?????0010011);
    wire inst_AUIPC = (inst == 32'b?????????????????????????0010111);
    wire inst_BEQ = (inst == 32'b?????????????????000?????1100011);
    wire inst_BGE = (inst == 32'b?????????????????101?????1100011);
    wire inst_BGEU = (inst == 32'b?????????????????111?????1100011);
    wire inst_BLT = (inst == 32'b?????????????????100?????1100011);
    wire inst_BLTU = (inst == 32'b?????????????????110?????1100011);
    wire inst_BNE = (inst == 32'b?????????????????001?????1100011);
    wire inst_C_ADD = (inst == 32'b????????????????1001??????????10);
    wire inst_C_ADDI = (inst == 32'b????????????????000???????????01);
    wire inst_C_ADDI16SP = (inst == 32'b????????????????011?00010?????01);
    wire inst_C_ADDI4SPN = (inst == 32'b????????????????000???????????00);
    wire inst_C_ADDIW = (inst == 32'b????????????????001???????????01);
    wire inst_C_ADDW = (inst == 32'b????????????????100111???01???01);
    wire inst_C_AND = (inst == 32'b????????????????100011???11???01);
    wire inst_C_ANDI = (inst == 32'b????????????????100?10????????01);
    wire inst_C_BEQZ = (inst == 32'b????????????????110???????????01);
    wire inst_C_BNEZ = (inst == 32'b????????????????111???????????01);
    wire inst_C_EBREAK = (inst == 32'b????????????????1001000000000010);
    wire inst_C_FLD = (inst == 32'b????????????????001???????????00);
    wire inst_C_FLDSP = (inst == 32'b????????????????001???????????10);
    wire inst_C_FLW = (inst == 32'b????????????????011???????????00);
    wire inst_C_FLWSP = (inst == 32'b????????????????011???????????10);
    wire inst_C_FSD = (inst == 32'b????????????????101???????????00);
    wire inst_C_FSDSP = (inst == 32'b????????????????101???????????10);
    wire inst_C_FSW = (inst == 32'b????????????????111???????????00);
    wire inst_C_FSWSP = (inst == 32'b????????????????111???????????10);
    wire inst_C_J = (inst == 32'b????????????????101???????????01);
    wire inst_C_JAL = (inst == 32'b????????????????001???????????01);
    wire inst_C_JALR = (inst == 32'b????????????????1001?????0000010);
    wire inst_C_JR = (inst == 32'b????????????????1000?????0000010);
    wire inst_C_LD = (inst == 32'b????????????????011???????????00);
    wire inst_C_LDSP = (inst == 32'b????????????????011???????????10);
    wire inst_C_LI = (inst == 32'b????????????????010???????????01);
    wire inst_C_LUI = (inst == 32'b????????????????011???????????01);
    wire inst_C_LW = (inst == 32'b????????????????010???????????00);
    wire inst_C_LWSP = (inst == 32'b????????????????010???????????10);
    wire inst_C_MV = (inst == 32'b????????????????1000??????????10);
    wire inst_C_NOP = (inst == 32'b????????????????000?00000?????01);
    wire inst_C_OR = (inst == 32'b????????????????100011???10???01);
    wire inst_C_SD = (inst == 32'b????????????????111???????????00);
    wire inst_C_SDSP = (inst == 32'b????????????????111???????????10);
    wire inst_C_SLLI = (inst == 32'b????????????????000???????????10);
    wire inst_C_SRAI = (inst == 32'b????????????????100?01????????01);
    wire inst_C_SRLI = (inst == 32'b????????????????100?00????????01);
    wire inst_C_SUB = (inst == 32'b????????????????100011???00???01);
    wire inst_C_SUBW = (inst == 32'b????????????????100111???00???01);
    wire inst_C_SW = (inst == 32'b????????????????110???????????00);
    wire inst_C_SWSP = (inst == 32'b????????????????110???????????10);
    wire inst_C_XOR = (inst == 32'b????????????????100011???01???01);
    wire inst_DIV = (inst == 32'b0000001??????????100?????0110011);
    wire inst_DIVU = (inst == 32'b0000001??????????101?????0110011);
    wire inst_DIVUW = (inst == 32'b0000001??????????101?????0111011);
    wire inst_DIVW = (inst == 32'b0000001??????????100?????0111011);
    wire inst_DRET = (inst == 32'b01111011001000000000000001110011);
    wire inst_EBREAK = (inst == 32'b00000000000100000000000001110011);
    wire inst_ECALL = (inst == 32'b00000000000000000000000001110011);
    wire inst_FADD_D = (inst == 32'b0000001??????????????????1010011);
    wire inst_FADD_S = (inst == 32'b0000000??????????????????1010011);
    wire inst_FCLASS_D = (inst == 32'b111000100000?????001?????1010011);
    wire inst_FCLASS_S = (inst == 32'b111000000000?????001?????1010011);
    wire inst_FCVT_D_L = (inst == 32'b110100100010?????????????1010011);
    wire inst_FCVT_D_LU = (inst == 32'b110100100011?????????????1010011);
    wire inst_FCVT_D_S = (inst == 32'b010000100000?????????????1010011);
    wire inst_FCVT_D_W = (inst == 32'b110100100000?????????????1010011);
    wire inst_FCVT_D_WU = (inst == 32'b110100100001?????????????1010011);
    wire inst_FCVT_L_D = (inst == 32'b110000100010?????????????1010011);
    wire inst_FCVT_L_S = (inst == 32'b110000000010?????????????1010011);
    wire inst_FCVT_LU_D = (inst == 32'b110000100011?????????????1010011);
    wire inst_FCVT_LU_S = (inst == 32'b110000000011?????????????1010011);
    wire inst_FCVT_S_D = (inst == 32'b010000000001?????????????1010011);
    wire inst_FCVT_S_L = (inst == 32'b110100000010?????????????1010011);
    wire inst_FCVT_S_LU = (inst == 32'b110100000011?????????????1010011);
    wire inst_FCVT_S_W = (inst == 32'b110100000000?????????????1010011);
    wire inst_FCVT_S_WU = (inst == 32'b110100000001?????????????1010011);
    wire inst_FCVT_W_D = (inst == 32'b110000100000?????????????1010011);
    wire inst_FCVT_W_S = (inst == 32'b110000000000?????????????1010011);
    wire inst_FCVT_WU_D = (inst == 32'b110000100001?????????????1010011);
    wire inst_FCVT_WU_S = (inst == 32'b110000000001?????????????1010011);
    wire inst_FDIV_D = (inst == 32'b0001101??????????????????1010011);
    wire inst_FDIV_S = (inst == 32'b0001100??????????????????1010011);
    wire inst_FENCE = (inst == 32'b?????????????????000?????0001111);
    wire inst_FENCE_TSO = (inst == 32'b100000110011?????000?????0001111);
    wire inst_FEQ_D = (inst == 32'b1010001??????????010?????1010011);
    wire inst_FEQ_S = (inst == 32'b1010000??????????010?????1010011);
    wire inst_FLD = (inst == 32'b?????????????????011?????0000111);
    wire inst_FLE_D = (inst == 32'b1010001??????????000?????1010011);
    wire inst_FLE_S = (inst == 32'b1010000??????????000?????1010011);
    wire inst_FLT_D = (inst == 32'b1010001??????????001?????1010011);
    wire inst_FLT_S = (inst == 32'b1010000??????????001?????1010011);
    wire inst_FLW = (inst == 32'b?????????????????010?????0000111);
    wire inst_FMADD_D = (inst == 32'b?????01??????????????????1000011);
    wire inst_FMADD_S = (inst == 32'b?????00??????????????????1000011);
    wire inst_FMAX_D = (inst == 32'b0010101??????????001?????1010011);
    wire inst_FMAX_S = (inst == 32'b0010100??????????001?????1010011);
    wire inst_FMIN_D = (inst == 32'b0010101??????????000?????1010011);
    wire inst_FMIN_S = (inst == 32'b0010100??????????000?????1010011);
    wire inst_FMSUB_D = (inst == 32'b?????01??????????????????1000111);
    wire inst_FMSUB_S = (inst == 32'b?????00??????????????????1000111);
    wire inst_FMUL_D = (inst == 32'b0001001??????????????????1010011);
    wire inst_FMUL_S = (inst == 32'b0001000??????????????????1010011);
    wire inst_FMV_D_X = (inst == 32'b111100100000?????000?????1010011);
    wire inst_FMV_S_X = (inst == 32'b111100000000?????000?????1010011);
    wire inst_FMV_W_X = (inst == 32'b111100000000?????000?????1010011);
    wire inst_FMV_X_D = (inst == 32'b111000100000?????000?????1010011);
    wire inst_FMV_X_S = (inst == 32'b111000000000?????000?????1010011);
    wire inst_FMV_X_W = (inst == 32'b111000000000?????000?????1010011);
    wire inst_FNMADD_D = (inst == 32'b?????01??????????????????1001111);
    wire inst_FNMADD_S = (inst == 32'b?????00??????????????????1001111);
    wire inst_FNMSUB_D = (inst == 32'b?????01??????????????????1001011);
    wire inst_FNMSUB_S = (inst == 32'b?????00??????????????????1001011);
    wire inst_FSD = (inst == 32'b?????????????????011?????0100111);
    wire inst_FSGNJ_D = (inst == 32'b0010001??????????000?????1010011);
    wire inst_FSGNJ_S = (inst == 32'b0010000??????????000?????1010011);
    wire inst_FSGNJN_D = (inst == 32'b0010001??????????001?????1010011);
    wire inst_FSGNJN_S = (inst == 32'b0010000??????????001?????1010011);
    wire inst_FSGNJX_D = (inst == 32'b0010001??????????010?????1010011);
    wire inst_FSGNJX_S = (inst == 32'b0010000??????????010?????1010011);
    wire inst_FSQRT_D = (inst == 32'b010110100000?????????????1010011);
    wire inst_FSQRT_S = (inst == 32'b010110000000?????????????1010011);
    wire inst_FSUB_D = (inst == 32'b0000101??????????????????1010011);
    wire inst_FSUB_S = (inst == 32'b0000100??????????????????1010011);
    wire inst_FSW = (inst == 32'b?????????????????010?????0100111);
    wire inst_JAL = (inst == 32'b?????????????????????????1101111);
    wire inst_JALR = (inst == 32'b?????????????????000?????1100111);
    wire inst_LB = (inst == 32'b?????????????????000?????0000011);
    wire inst_LBU = (inst == 32'b?????????????????100?????0000011);
    wire inst_LD = (inst == 32'b?????????????????011?????0000011);
    wire inst_LH = (inst == 32'b?????????????????001?????0000011);
    wire inst_LHU = (inst == 32'b?????????????????101?????0000011);
    wire inst_LR_D = (inst == 32'b00010??00000?????011?????0101111);
    wire inst_LR_W = (inst == 32'b00010??00000?????010?????0101111);
    wire inst_LUI = (inst == 32'b?????????????????????????0110111);
    wire inst_LW = (inst == 32'b?????????????????010?????0000011);
    wire inst_LWU = (inst == 32'b?????????????????110?????0000011);
    wire inst_MRET = (inst == 32'b00110000001000000000000001110011);
    wire inst_MUL = (inst == 32'b0000001??????????000?????0110011);
    wire inst_MULH = (inst == 32'b0000001??????????001?????0110011);
    wire inst_MULHSU = (inst == 32'b0000001??????????010?????0110011);
    wire inst_MULHU = (inst == 32'b0000001??????????011?????0110011);
    wire inst_MULW = (inst == 32'b0000001??????????000?????0111011);
    wire inst_OR = (inst == 32'b0000000??????????110?????0110011);
    wire inst_ORI = (inst == 32'b?????????????????110?????0010011);
    wire inst_PAUSE = (inst == 32'b00000001000000000000000000001111);
    wire inst_REM = (inst == 32'b0000001??????????110?????0110011);
    wire inst_REMU = (inst == 32'b0000001??????????111?????0110011);
    wire inst_REMUW = (inst == 32'b0000001??????????111?????0111011);
    wire inst_REMW = (inst == 32'b0000001??????????110?????0111011);
    wire inst_SB = (inst == 32'b?????????????????000?????0100011);
    wire inst_SBREAK = (inst == 32'b00000000000100000000000001110011);
    wire inst_SC_D = (inst == 32'b00011????????????011?????0101111);
    wire inst_SC_W = (inst == 32'b00011????????????010?????0101111);
    wire inst_SCALL = (inst == 32'b00000000000000000000000001110011);
    wire inst_SD = (inst == 32'b?????????????????011?????0100011);
    wire inst_SH = (inst == 32'b?????????????????001?????0100011);
    wire inst_SLL = (inst == 32'b0000000??????????001?????0110011);
    wire inst_SLLI = (inst == 32'b000000???????????001?????0010011);
    wire inst_SLLI_RV32 = (inst == 32'b0000000??????????001?????0010011);
    wire inst_SLLIW = (inst == 32'b0000000??????????001?????0011011);
    wire inst_SLLW = (inst == 32'b0000000??????????001?????0111011);
    wire inst_SLT = (inst == 32'b0000000??????????010?????0110011);
    wire inst_SLTI = (inst == 32'b?????????????????010?????0010011);
    wire inst_SLTIU = (inst == 32'b?????????????????011?????0010011);
    wire inst_SLTU = (inst == 32'b0000000??????????011?????0110011);
    wire inst_SRA = (inst == 32'b0100000??????????101?????0110011);
    wire inst_SRAI = (inst == 32'b010000???????????101?????0010011);
    wire inst_SRAI_RV32 = (inst == 32'b0100000??????????101?????0010011);
    wire inst_SRAIW = (inst == 32'b0100000??????????101?????0011011);
    wire inst_SRAW = (inst == 32'b0100000??????????101?????0111011);
    wire inst_SRL = (inst == 32'b0000000??????????101?????0110011);
    wire inst_SRLI = (inst == 32'b000000???????????101?????0010011);
    wire inst_SRLI_RV32 = (inst == 32'b0000000??????????101?????0010011);
    wire inst_SRLIW = (inst == 32'b0000000??????????101?????0011011);
    wire inst_SRLW = (inst == 32'b0000000??????????101?????0111011);
    wire inst_SUB = (inst == 32'b0100000??????????000?????0110011);
    wire inst_SUBW = (inst == 32'b0100000??????????000?????0111011);
    wire inst_SW = (inst == 32'b?????????????????010?????0100011);
    wire inst_WFI = (inst == 32'b00010000010100000000000001110011);
    wire inst_XOR = (inst == 32'b0000000??????????100?????0110011);
    wire inst_XORI = (inst == 32'b?????????????????100?????0010011);
    wire inst_CSRRC = (inst == 32'b?????????????????011?????1110011);
    wire inst_CSRRCI = (inst == 32'b?????????????????111?????1110011);
    wire inst_CSRRS = (inst == 32'b?????????????????010?????1110011);
    wire inst_CSRRSI = (inst == 32'b?????????????????110?????1110011);
    wire inst_CSRRW = (inst == 32'b?????????????????001?????1110011);
    wire inst_CSRRWI = (inst == 32'b?????????????????101?????1110011);

    wire isRVC = (inst[1:0] != 2'b11);
    wire isAdd = inst_ADD | inst_ADDI | inst_ADDW | inst_ADDIW | inst_C_ADD | inst_C_ADDI | inst_C_ADDI16SP | inst_C_ADDI4SPN | inst_C_ADDIW | inst_C_ADDW;
    wire isSub = inst_SUB | inst_SUBW | inst_C_SUB | inst_C_SUBW;
    wire isShift = inst_SLL | inst_SLLI | inst_SLLW | inst_SLLIW | inst_SRL | inst_SRLI | inst_SRLW | inst_SRLIW | inst_SRA | inst_SRAI | inst_SRAW | inst_SRAIW | inst_C_SRAI | inst_C_SRLI | inst_C_SLLI;
    wire isLogic = inst_AND | inst_ANDI | inst_OR | inst_ORI | inst_XOR | inst_XORI;
    wire isCompare = inst_SLT | inst_SLTI | inst_SLTU | inst_SLTIU;
    wire isConditionalBranch = inst_BEQ | inst_BGE | inst_BGEU | inst_BLT | inst_BLTU | inst_BNE;
    wire isDirectBranch = inst_JAL | inst_JALR;
    wire isLoad = inst_LB | inst_LBU | inst_LH | inst_LHU | inst_LW | inst_LWU | inst_LD;
    wire isStore = inst_SB | inst_SH | inst_SW | inst_SD;
    wire isMul = inst_MUL | inst_MULH | inst_MULHSU | inst_MULHU | inst_MULW;
    wire isDiv = inst_DIV | inst_DIVU | inst_DIVUW | inst_DIVW | inst_REM | inst_REMU | inst_REMUW | inst_REMW;
    wire isCSR = inst_CSRRC | inst_CSRRCI | inst_CSRRS | inst_CSRRSI | inst_CSRRW | inst_CSRRWI;
    wire isUnknow = !(isAdd | isSub | isShift | isLogic | isCompare | isConditionalBranch | isDirectBranch | isLoad | isStore | isMul | isDiv | isCSR);
    // TODO: add compressed inst
    // integer math (with rs1 rs2)
    wire isIntMath = isAdd | isSub | isShift | isLogic | isCompare;
    // replace rs2 to imm
    wire isImmMath = inst_ADDI | inst_ADDIW | inst_SLLI | inst_SLLIW | inst_SRLI | inst_SRLIW | inst_SRAI | inst_SRAIW;
    wire use_imm = isImmMath;

    wire[`WDEF(5)] ilrd_idx = inst[11:7];
    wire[`WDEF(5)] ilrs1_idx = inst[19:15];
    wire[`WDEF(5)] ilrs2_idx = inst[24:20];
    wire[`WDEF(12)] csr_idx = inst[31:20];

    wire isCall = inst_JALR & (ilrd_idx==1) & (ilrs1_idx==1);
    wire isRet = inst_JALR & (ilrd_idx==0) & (ilrs1_idx==1) & (inst[31:20]==0);

    wire has_rd = !(isBranch || isStore) && (ilrd_idx != 0);
    wire has_rs1 = !(inst_JAL);
    wire has_rs2 = !(isImmMath || isDirectBranch);


    //jalr、load、opimm
    wire [19:0] inst_i_type_imm = {{8{inst[31]}}, inst[31:20]};
    //store
    wire [19:0] inst_s_type_imm = {{8{inst[31]}}, inst[31:25], inst[11:7]};
    //lui、auipc, need to shift when use
    wire [19:0] inst_u_type_imm = inst[31:12];
    //jal
    wire [19:0] inst_j_type_imm = {inst[19:12], inst[20], inst[30:21], 1'b0};
    //branch
    wire [19:0] inst_b_type_imm = {{8{inst[31]}}, inst[7], inst[30:25], inst[11:8], 1'b0};
    //{csr_idx,csr_zimm}
    wire [19:0] inst_csr_type_imm = {3'd0, csr_idx ,inst[19:15]};
    //shift
    wire [19:0] inst_shift_type_imm = {15'h0, inst[24:20]};

    wire[19:0] inst_opimm_imm = (inst_SLLI | inst_SLLIW | inst_SRLI | inst_SRLIW | inst_SRAI | inst_SRAIW) ?
                                inst_shift_type_imm : inst_i_type_imm;

    wire[`IMMDEF] imm =
    inst_LUI | inst_AUIPC ? inst_u_type_imm   :
    isConditionalBranch ? inst_b_type_imm            :
    isStore ? inst_s_type_imm             :
    isLoad | inst_JALR ? inst_i_type_imm              :
    isImmMath ? inst_opimm_imm              :
    inst_JAL ? inst_j_type_imm :
    isCSR ? inst_csr_type_imm :
    0;

    wire isnop = (isIntMath) && (rd == 0);
    wire ismv = (inst_addi) && (rd == rs1) && (imm == 0);

    /********************************************************/
    //regfile write enable
    wire rd_wen =
    (rd != 0) &
    (opc_lui    |
    opc_auipc   |
    opc_jal     |
    opc_jalr    |
    opc_opimm   |
    opc_op      |
    opc_system  |
    opc_load);

    //寄存器读使能1
    wire ilrs1_ren =
    (rs1!=0 ) &
    (opc_jalr   |
    opc_branch  |
    opc_load    |
    opc_store   |
    opc_opimm   |
    opc_op      |
    inst_csrrw  |
    inst_csrrs  |
    inst_csrrc);

    //寄存器读使能2
    wire ilrs2_ren = (rs2 != 0) & (opc_branch | opc_store | opc_op);


    //dispQue select
    wire[`WDEF(2)] dispQue_id =
    !(isLoad || isStore) ? `INTBLOCK_ID :
    (isLoad || isStore) ?  `MEMBLOCK_ID :
    0;
    //issueQue select
    wire[`WDEF(2)] issueQue_id =
    (isIntMath | isImmMath) ? `ALUIQ_ID :
    (isMul | isDiv) ? `MDUIQ_ID :
    `MISCIQ_ID;

    //ALU
    MicOp_t::_alu aluop_type =
    inst_LUI ? MicOp_t::lui :
    (inst_ADD | inst_ADDI) ? MicOp_t::add :
    (inst_SUB)  ? MicOp_t::sub :
    (inst_ADDW | inst_ADDIW) ? MicOp_t::addw :
    (inst_SUBW) ? MicOp_t::subw :
    (inst_SLL | inst_SLLI) ? MicOp_t::sll :
    (inst_SRL | inst_SRLI) ? MicOp_t::srl :
    (inst_SRA | inst_SRAI) ? MicOp_t::sra :
    (inst_SLLW | inst_SLLIW) ? MicOp_t::sllw :
    (inst_SRLW | inst_SRLIW) ? MicOp_t::srlw :
    (inst_SRAW | inst_SRAIW) ? MicOp_t::sraw :
    (inst_XOR | inst_XORI) ? MicOp_t::_xor :
    (inst_OR | inst_ORI) ? MicOp_t::_or :
    (inst_AND | inst_ANDI) ? MicOp_t::_and :
    (inst_SLT | inst_SLTI) ? MicOp_t::slt :
    (inst_SLTU | inst_SLTIU) ? MicOp_t::sltu :
    MicOp_t::none;
    wire use_alu = (aluop_type != MicOp_t::none);

    //MDU
    MicOp_t::_mdu mduop_type =
    inst_MUL ? MicOp_t::mul :
    inst_MULW ? MicOp_t::mulw :
    inst_MULH ? MicOp_t::mulh :
    inst_MULHU ? MicOp_t::mulhu :
    inst_MULHSU ? MicOp_t::mulhsu :
    inst_DIV ? MicOp_t::div :
    inst_DIVW ? MicOp_t::divw :
    inst_DIVU ? MicOp_t::divu :
    inst_REM ? MicOp_t::rem :
    inst_REMW ? MicOp_t::remw :
    inst_REMU ? MicOp_t::remu :
    inst_REMUW ? MicOp_t::remuw :
    MicOp_t::none;
    wire use_mdu = (mduop_type != MicOp_t::none);

    assign o_decinfo.isRVC = isRVC;
    assign o_decinfo.ismv = ismv;
    assign o_decinfo.pc = i_inst_pc;
    assign o_decinfo.npc = i_inst_npc;
    assign o_decinfo.imm20 = imm;
    assign o_decinfo.rd_wen = rd_wen;
    assign o_decinfo.ilrd_idx = ilrd_idx;
    assign o_decinfo.ilrs_idx[0] = has_rs1 ? ilrs1_idx : 0;
    assign o_decinfo.ilrs_idx[1] = has_rs2 ? ilrs2_idx : 0;
    assign o_decinfo.use_imm = use_imm;
    assign o_decinfo.dispQue_id = dispQue_id;
    assign o_decinfo.issueQue_id = issueQue_id;

    assign o_decinfo.micOp_type =
    use_alu ? aluop_type :
    use_mdu ? mduop_type :
    0;

    assign o_unknow_inst = isUnknow;



endmodule
