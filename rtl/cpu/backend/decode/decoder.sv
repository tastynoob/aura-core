`include "decode_define.svh"


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
    input wire clk,
    input wire rst,

    input wire [`IDEF] i_inst,
    input wire[`XDEF] i_pc,
    //decinfo output
    //serialize execute, such as csr r/w
    output wire o_need_serialize,
    //we can get the jal inst taken pc at decode
    output wire o_inst_jal,
    output wire[`XDEF] o_jal_takenpc,
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
    wire isBranch = inst_BEQ | inst_BGE | inst_BGEU | inst_BLT | inst_BLTU | inst_BNE;
    wire isJump = inst_JAL | inst_JALR;
    wire isLoad = inst_LB | inst_LBU | inst_LH | inst_LHU | inst_LW | inst_LWU | inst_LD;
    wire isStore = inst_SB | inst_SH | inst_SW | inst_SD;
    wire isMul = inst_MUL | inst_MULH | inst_MULHSU | inst_MULHU | inst_MULW;
    wire isDiv = inst_DIV | inst_DIVU | inst_DIVUW | inst_DIVW | inst_REM | inst_REMU | inst_REMUW | inst_REMW;
    wire isCSR = inst_CSRRC | inst_CSRRCI | inst_CSRRS | inst_CSRRSI | inst_CSRRW | inst_CSRRWI;

    // TODO: add compressed inst
    // integer math (with rs1 rs2)
    wire isIntMath = isAdd | isSub | isShift | isLogic | isCompare;
    // replace rs2 to imm
    wire useImm = inst_ADDI | inst_ADDIW | inst_C_ADDI | inst_SLLI | inst_SLLIW | inst_SRLI | inst_SRLIW | inst_SRAI | inst_SRAIW;

    wire[4:0] rd_idx = inst[11:7];
    wire[4:0] rs1_idx = inst[19:15];
    wire[4:0] rs2_idx = inst[24:20];

    wire isCall = inst_JALR & (rd_idx==1) & (rs1_idx==1);
    wire isRet = inst_JALR & (rd_idx==0) & (rs1_idx==1) & (inst[31:20]==0);

    /*********************************************************/
    wire has_rd = !(isBranch || isStore);
    wire has_rs1 = !(inst_JAL);
    wire has_rs2;


    // 指令中的立即数
    //jalr、load、opimm
    wire [19:0] inst_i_type_imm = {{8{inst[31]}}, inst[31:20]};
    //store
    wire [19:0] inst_s_type_imm = {{8{inst[31]}}, inst[31:25], inst[11:7]};
    //lui、auipc
    wire [19:0] inst_u_type_imm = inst[31:12];
    //jal
    wire [19:0] inst_j_type_imm = {inst[19:12], inst[20], inst[30:21], 1'b0};
    //branch
    wire [19:0] inst_b_type_imm = {{8{inst[31]}}, inst[7], inst[30:25], inst[11:8], 1'b0};
    //csr zimm
    wire [19:0] inst_csr_type_imm = {15'h0, inst[19:15]};
    //shift
    wire [19:0] inst_shift_type_imm = {15'h0, inst[24:20]};

    wire[19:0] inst_opimm_imm = (inst_SLLI | inst_SLLIW | inst_SRLI | inst_SRLIW | inst_SRAI | inst_SRAIW) ?
                                inst_shift_type_imm : inst_i_type_imm;
    //不需要译码jalr,jal的立即数
    //对于移位指令，由于移位只需要立即数低5位，高位省略，所以为了方便，直接将inst_i_type_imm当作shamt
    assign o_imm =  opc_lui | opc_auipc ? inst_u_type_imm   :
                    opc_branch ? inst_b_type_imm            :
                    opc_store ? inst_s_type_imm             :
                    opc_load ? inst_i_type_imm              :
                    opc_opimm ? inst_opimm_imm              :
                    0;

    wire isnop = (inst_addi) && (rd == rs1) && (inst_i_type_imm == 0);
    wire ismv = (inst_addi) && (rd != rs1);

    /********************************************************/
    //寄存器写使能
    assign o_decinfo.rd_en =
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
    assign o_decinfo.regIdx.rs1_en =
        ( rs1!=0 ) &
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
    assign o_decinfo.regIdx.rs2_en = (rs2 != 0) & (opc_branch | opc_store | opc_op);

    Fu_t::_ fu_type;
    MicOp_t::_u micop_type;
    //fu select
    assign fu_type =
        opc_opimm | (opc_op & (~inst_expand_M)) |opc_branch ? Fu_t::alu :
        inst_expand_M ? Fu_t::mdu :
        opc_load ? Fu_t::ldu :
        opc_store ? Fu_t::stu :
        Fu_t::none;

    //micro op select

    //ALU
    MicOp_t::_alu aluop_type;
    assign aluop_type =
    inst_add | inst_addi ? MicOp_t::add :
    inst_addw | inst_addiw ? MicOp_t::addw :
    inst_sub ? MicOp_t::sub :
    inst_subw ? MicOp_t::subw :
    MicOp_t::none;


    //将rs1输出替换为pc
    assign o_rs1topc = opc_auipc;
    //将rs2输出替换成立即数,lui,auipc,opc,_imm
    assign o_rs2toimm = opc_lui | opc_auipc | opc_opimm | opc_load | opc_store;

    //LSU
    // wire[`DECINFOLEN_DEF] lsuinfo;
    // assign lsuinfo[`LSUINFO_WRCS] = opc_store;//读为0,写为1
    // //3种掩码
    // assign lsuinfo[`LSUINFO_OPB] = func_000 |  func_100;//字节
    // assign lsuinfo[`LSUINFO_OPH] = func_001 |  func_101;//半字
    // assign lsuinfo[`LSUINFO_OPW] = func_010;//全字
    // assign lsuinfo[`LSUINFO_LU] = func_100 | func_101;//无符号拓展

    //BJU
    // wire[`DECINFOLEN_DEF] bjuinfo;
    // assign bjuinfo[`BJUINFO_JAL]=opc_jal | opc_jalr;
    // assign bjuinfo[`BJUINFO_BEQ]=inst_beq;
    // assign bjuinfo[`BJUINFO_BNE]=inst_bne;
    // assign bjuinfo[`BJUINFO_BLT]=inst_blt;
    // assign bjuinfo[`BJUINFO_BGE]=inst_bge;
    // assign bjuinfo[`BJUINFO_BLTU]=inst_bltu;
    // assign bjuinfo[`BJUINFO_BGEU]=inst_bgeu;
    // assign bjuinfo[`BJUINFO_BPU_BFLAG]=i_bpu_bflag;//分支预测跳转标志

    //MDU
    // wire[`DECINFOLEN_DEF] mduinfo;
    // assign mduinfo[`MDUINFO_MUL]    =inst_mul;
    // assign mduinfo[`MDUINFO_MULH]   =inst_mulh;
    // assign mduinfo[`MDUINFO_MULHSU] =inst_mulhsu;
    // assign mduinfo[`MDUINFO_MULHU]  =inst_mulhu;
    // assign mduinfo[`MDUINFO_DIV]    =inst_div;
    // assign mduinfo[`MDUINFO_DIVU]   =inst_divu;
    // assign mduinfo[`MDUINFO_REM]    =inst_rem;
    // assign mduinfo[`MDUINFO_REMU]   =inst_remu;




    //读csr寄存器的条件：sys指令、func不为0
    //当前是csrrw或csrrwi指令时,rdidx不为0
    // assign o_csr_ren = opc_system & (|func) & ((inst_csrrw & inst_csrrwi) ? (rd != 0) : 1);
    // //csr索引
    // assign o_csridx = {`CSRIDX_DEF{o_csr_ren}} & i_inst[31:20];
    // //func[2]==1说明是立即数
    // assign o_zimm = {`XLEN{o_csr_ren & func[2]}} & inst_csr_type_imm;

    //SCU
    // wire [`DECINFOLEN_DEF] scuinfo;
    // assign scuinfo[`SCUINFO_ECALL] = inst_ecall;
    // assign scuinfo[`SCUINFO_EBREAK] = inst_ebreak;
    // assign scuinfo[`SCUINFO_CSRRW] = inst_csrrw | inst_csrrwi;
    // assign scuinfo[`SCUINFO_CSRRS] = inst_csrrs | inst_csrrsi;
    // assign scuinfo[`SCUINFO_CSRRC] = inst_csrrc | inst_csrrci;
    // assign scuinfo[`SCUINFO_CSRIMM] = func[2];
    //写csr寄存器的条件:
    //当前是csrrs或csrrc指令,rs1idx不为0
    //当前是csrrsi或csrrci,zimm不为0
    // assign scuinfo[`SCUINFO_CSRWEN] =
    //     (inst_csrrs | inst_csrrsi | inst_csrrc | inst_csrrci) ? (rs1!=0) : |func;//只有rs1idx!=0才能写





    // assign o_decinfo_grp = decinfo_grp;
    // assign o_decinfo =  ({`DECINFOLEN{decinfo_grp[`DECINFO_GRP_ALU]}}   & aluinfo) |
    //                     ({`DECINFOLEN{decinfo_grp[`DECINFO_GRP_LSU]}}   & lsuinfo) |
    //                     ({`DECINFOLEN{decinfo_grp[`DECINFO_GRP_BJU]}}   & bjuinfo) |
    //                     ({`DECINFOLEN{decinfo_grp[`DECINFO_GRP_MDU]}}   & mduinfo) |
    //                     ({`DECINFOLEN{decinfo_grp[`DECINFO_GRP_SCU]}}   & scuinfo) ;




endmodule
