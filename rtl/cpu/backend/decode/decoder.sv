`include "decode_define.svh"


//对于branch指令
//需要计算:rs1比较人数,优先以rs1与rs2的比较计算
//pc + imm


//lui: rd = x0 + imm
//auipc : rd = pc + imm
//jal,jalr : rd = pc
//mark the (mv x1,x1)-like as nop
//TODO: finish decode
module decoder (
    input wire clk,
    input wire rst,

    input wire [`IDEF] i_inst,
    //decinfo output
    output decinfo_t o_decinfo
);

    //rvc , the first two bit is not 11
    wire rvc = !(i_inst[1] & i_inst[0]);

    // 32位取出指令中的每一个域
    wire [4:0] opc = i_inst[6:2];
    wire [4:0] rd = i_inst[11:7];
    wire [2:0] func = i_inst[14:12];
    wire [6:0] func7 = i_inst[31:25];
    wire [4:0] rs1 = i_inst[19:15];
    wire [4:0] rs2 = i_inst[24:20];
    wire [11:0] type_i_imm_11_0 = i_inst[31:20];
    wire [6:0] type_s_imm_11_5 = i_inst[31:25];
    wire [4:0] type_s_imm_4_0 = i_inst[11:7];
    wire [6:0] type_b_imm_12_10_5 = i_inst[31:25];
    wire [4:0] type_b_imm_4_1_11 = i_inst[11:7];
    wire [19:0] type_u_imm_31_12 = i_inst[31:12];
    wire [19:0] type_j_imm_31_12 = i_inst[31:12];

    // 指令opc域的取值
    wire opc_lui = (opc == `OPC_LUI);
    wire opc_auipc = (opc == `OPC_AUIPC);
    wire opc_jal = (opc == `OPC_JAL);
    wire opc_jalr = (opc == `OPC_JALR);
    wire opc_branch = (opc == `OPC_BRANCH);
    wire opc_load = (opc == `OPC_LOAD);
    wire opc_store = (opc == `OPC_STORE);
    wire opc_opimm = (opc == `OPC_OPIMM);
    wire opc_op = (opc == `OPC_OP);
    wire opc_64im = (opc == `OPC_64IM);
    wire opc_fence = (opc == `OPC_FENCE);
    wire opc_system = (opc == `OPC_SYSTEM);

    // 指令func域的取值
    wire func_000 = (func == 3'b000);
    wire func_001 = (func == 3'b001);
    wire func_010 = (func == 3'b010);
    wire func_011 = (func == 3'b011);
    wire func_100 = (func == 3'b100);
    wire func_101 = (func == 3'b101);
    wire func_110 = (func == 3'b110);
    wire func_111 = (func == 3'b111);

    // 指令func7域的取值
    wire func7_0000000 = (func7 == 7'b0000000);
    wire func7_0100000 = (func7 == 7'b0100000);
    wire func7_0000001 = (func7 == 7'b0000001);

    // I类型指令imm域的取值
    wire type_i_imm_000000000000 = (type_i_imm_11_0 == 12'b000000000000);
    wire type_i_imm_000000000001 = (type_i_imm_11_0 == 12'b000000000001);

    /*********************************************************/
    // 译码出具体指令
    /*j*/
    wire inst_lui = opc_lui;
    wire inst_auipc = opc_auipc;
    wire inst_jal = opc_jal;
    wire inst_jalr = opc_jalr & func_000;
    /*branch*/
    wire inst_beq = opc_branch & func_000;
    wire inst_bne = opc_branch & func_001;
    wire inst_blt = opc_branch & func_100;
    wire inst_bge = opc_branch & func_101;
    wire inst_bltu = opc_branch & func_110;
    wire inst_bgeu = opc_branch & func_111;
    /*load*/
    wire inst_lb = opc_load & func_000;
    wire inst_lh = opc_load & func_001;
    wire inst_lw = opc_load & func_010;
    wire inst_lbu = opc_load & func_100;
    wire inst_lhu = opc_load & func_101;
    wire inst_lwu = opc_load & func_110;
    wire inst_ld = opc_load & func_011;
    /*store*/
    wire inst_sb = opc_store & func_000;
    wire inst_sh = opc_store & func_001;
    wire inst_sw = opc_store & func_010;
    wire inst_sd = opc_store & func_011;
    /*opimm*/
    wire inst_addi = opc_opimm & func_000;
    wire inst_slti = opc_opimm & func_010;
    wire inst_sltiu = opc_opimm & func_011;
    wire inst_xori = opc_opimm & func_100;
    wire inst_ori = opc_opimm & func_110;
    wire inst_andi = opc_opimm & func_111;
    wire inst_slli = opc_opimm & func_001 & func7_0000000;
    wire inst_srli = opc_opimm & func_101 & func7_0000000;
    wire inst_srai = opc_opimm & func_101 & func7_0100000;
    wire inst_addiw;
    wire inst_slliw;
    wire inst_srliw;
    wire inst_sraiw;
    /*op*/
    wire inst_add = opc_op & func_000 & func7_0000000;
    wire inst_sub = opc_op & func_000 & func7_0100000;
    wire inst_sll = opc_op & func_001 & func7_0000000;
    wire inst_slt = opc_op & func_010 & func7_0000000;
    wire inst_sltu = opc_op & func_011 & func7_0000000;
    wire inst_xor = opc_op & func_100 & func7_0000000;
    wire inst_srl = opc_op & func_101 & func7_0000000;
    wire inst_sra = opc_op & func_101 & func7_0100000;
    wire inst_or = opc_op & func_110 & func7_0000000;
    wire inst_and = opc_op & func_111 & func7_0000000;
    wire inst_addw;
    wire inst_subw;
    wire inst_sllw;
    wire inst_srlw;
    wire inst_sraw;
    /*fence*/
    wire inst_fence = opc_fence & func_000;
    wire inst_fencei = opc_fence & func_001;
    /*system*/
    wire inst_ecall = opc_system & func_000 & type_i_imm_000000000000;
    wire inst_ebreak = opc_system & func_000 & type_i_imm_000000000001;
    wire inst_csrrw = opc_system & func_001;
    wire inst_csrrs = opc_system & func_010;
    wire inst_csrrc = opc_system & func_011;
    wire inst_csrrwi = opc_system & func_101;
    wire inst_csrrsi = opc_system & func_110;
    wire inst_csrrci = opc_system & func_111;

    /*M拓展*/
    wire inst_mul = opc_op & func_000 & func7_0000001;
    wire inst_mulh = opc_op & func_001 & func7_0000001;
    wire inst_mulhsu = opc_op & func_010 & func7_0000001;
    wire inst_mulhu = opc_op & func_011 & func7_0000001;
    wire inst_div = opc_op & func_100 & func7_0000001;
    wire inst_divu = opc_op & func_101 & func7_0000001;
    wire inst_rem = opc_op & func_110 & func7_0000001;
    wire inst_remu = opc_op & func_111 & func7_0000001;
    wire inst_expand_M = opc_op & func7_0000001;

    /*********************************************************/



    // 指令中的立即数
    //lui、auipc
    wire [19:0] inst_u_type_imm = i_inst[31:12];
    //jal
    wire [19:0] inst_j_type_imm = {i_inst[19:12], i_inst[20], i_inst[30:21], 1'b0};
    //branch
    wire [19:0] inst_b_type_imm = {{8{i_inst[31]}}, i_inst[7], i_inst[30:25], i_inst[11:8], 1'b0};
    //store
    wire [19:0] inst_s_type_imm = {{8{i_inst[31]}}, i_inst[31:25], i_inst[11:7]};
    //jalr、load、opimm
    wire [19:0] inst_i_type_imm = {{8{i_inst[31]}}, i_inst[31:20]};
    //csr zimm
    wire [19:0] inst_csr_type_imm = {15'h0, i_inst[19:15]};
    //shift
    wire [19:0] inst_shift_type_imm = {15'h0, i_inst[24:20]};

    wire[19:0] inst_opimm_imm = (inst_slli | inst_srli | inst_srai) ?
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
    // //寄存器写使能
    // assign o_decinfo.regIdx.rd_en =
    //     (rd != 0) &
    //     (opc_lui    |
    //     opc_auipc   |
    //     opc_jal     |
    //     opc_jalr    |
    //     opc_opimm   |
    //     opc_op      |
    //     opc_system  |
    //     opc_load);

    // //寄存器读使能1
    // assign o_decinfo.regIdx.rs1_en =
    //     ( rs1!=0 ) &
    //     (opc_jalr   |
    //     opc_branch  |
    //     opc_load    |
    //     opc_store   |
    //     opc_opimm   |
    //     opc_op      |
    //     inst_csrrw  |
    //     inst_csrrs  |
    //     inst_csrrc);

    // //寄存器读使能2
    // assign o_decinfo.regIdx.rs2_en = (rs2 != 0) & (opc_branch | opc_store | opc_op);

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
