`ifndef __DECODE_DEFINE_SVH__
`define __DECODE_DEFINE_SVH__

`include "core_config.svh"

//addi xn,xn,0  空指令

//32位指令开头
`define OPC_TYPE32 2'b11

//需要计算
//需要写rd
//alu_b位为imm
`define OPC_LUI 5'b01101 // rd = imm
`define OPC_AUIPC 5'b00101 // rd = pc + imm
/*****************************************************/  //无条件跳转
`define OPC_JAL 5'b11011 // rd = pc + 4; pc += imm
`define OPC_JALR 5'b11001 // rd = pc+4;pc= ( rs1 + imm ) & ~1;
/*****************************************************/  //branch
`define OPC_BRANCH 5'b11000
`define FUNC_BEQ 3'b000 // if(rs1 == rs2) pc += imm; => if(rs1-rs2=0)
`define FUNC_BNE 3'b001 // if(rs1 != rs2) pc += imm; => if(rs1-rs2)
`define FUNC_BLT 3'b100 // if(rs1 < rs2)             => if(rs1 < rs2)
`define FUNC_BGE 3'b101 // if(rs1 >= rs2) pc += imm; => if(!(rs1 < rs2))
`define FUNC_BLTU 3'b110 // if(rs1 <u rs2)            => if(rs1 <u rs2)
`define FUNC_BGEU 3'b111 // if(rs1 >=u rs2)           => if(!(rs1 <u rs2))
/*****************************************************/  //load加载
`define OPC_LOAD 5'b00000
`define FUNC_LB 3'b000
`define FUNC_LH 3'b001
`define FUNC_LW 3'b010
`define FUNC_LBU 3'b100
`define FUNC_LHU 3'b101
/*****************************************************/  //store储存
`define OPC_STORE 5'b01000
`define FUNC_SB 3'b000
`define FUNC_SH 3'b001
`define FUNC_SW 3'b010
/*****************************************************/  //imm立即数指令
`define OPC_OPIMM 5'b00100
`define FUNC_ADDI 3'b000
`define FUNC_SLTI 3'b010
`define FUNC_SLTIU 3'b011
`define FUNC_XORI 3'b100
`define FUNC_ORI 3'b110
`define FUNC_ANDI 3'b111
`define FUNC_SLLI 3'b001
//特殊变种
`define FUNC_SRLI_SRAI 3'b101
`define FUNC7_SRLI 7'b0000000
`define FUNC7_SRAI 7'b0100000
/*****************************************************/  //op寄存器指令
`define OPC_OP 5'b01100
`define FUNC_ADD_SUB 3'b000
`define FUNC7_ADD 7'b0000000
`define FUNC7_SUB 7'b0100000
`define FUNC_SLL 3'b001
`define FUNC_SLT 3'b010
`define FUNC_SLTU 3'b011
`define FUNC_XOR 3'b100
`define FUNC_SRL_SRA 3'b101
`define FUNC7_SRL 7'b0000000
`define FUNC7_SRA 7'b0100000
`define FUNC_OR 3'b110
`define FUNC_AND 3'b111
/*****************************************************/  //fence
`define OPC_FENCE 5'b00011
`define FUNC_FENCE 3'b000
`define FUNC_FENCEI 3'b001
/*****************************************************/  //system系统指令
`define OPC_SYSTEM 5'b11100
`define FUNC_ECALL_EBREAK 3'b000
`define FUNC12_ECALL 12'b000000000000
`define FUNC12_EBREAK 12'b000000000001
`define FUNC_CSRRW 3'b001 //rd = csr,csr = rs1
`define FUNC_CSRRS 3'b010 //rd = csr,csr = csr | rs1
`define FUNC_CSRRC 3'b011 //rd = csr,csr = csr & ~rs1
`define FUNC_CSRRWI 3'b101 //rd = csr,csr = zimm
`define FUNC_CSRRSI 3'b110 //rd = csr,csr = csr | zimm
`define FUNC_CSRRCI 3'b111 //rd = csr,csr = csr & ~zimm,
/*****************************************************/  //rv64m extension
`define OPC_64IM 5'b01110

package Fu_t;
    typedef enum logic [
    `WDEF(5)
    ] {
        none = 0,
        alu,
        mdu,
        ldu,
        stu,
        misc,
        mv,  //used fot move elim
        nop  //nop
    } _;
endpackage

package MicOp_t;
    `define MICOP_WIDTH 5
    const logic [`WDEF(`MICOP_WIDTH)] none = 0;
    typedef enum logic [
    `WDEF(`MICOP_WIDTH)
    ] {
        //arithmetic
        lui = 5'b0_1000,  // 8
        add,
        sub,
        addw,
        subw,
        //shift
        sll,
        srl,
        sra,
        sllw,
        srlw,
        sraw,
        //logical
        _xor,
        _or,
        _and,
        slt,  // dst = (src1 - src2)[-1]
        sltu  // dst = (src1 - src2)[-1] == src1[-1]
    } _alu;
    typedef enum logic [
    `WDEF(`MICOP_WIDTH)
    ] {
        auipc = 5'b0_1000,
        //unconditional branch
        jal,
        jalr,
        //conditional branch
        beq,
        bne,
        blt,
        bge,
        bltu,
        bgeu
    } _bru;
    typedef enum logic [
    `WDEF(`MICOP_WIDTH)
    ] {
        mret   = 5'b0_1000,
        sret,
        ecall,
        ebreak,
        csrrw,
        csrrc,
        csrrs,
        csrrwi,
        csrrci,
        csrrsi
    } _scu;
    typedef enum logic [
    `WDEF(`MICOP_WIDTH)
    ] {
        mul = 5'b0_1000,
        mulw,
        mulh,
        mulhu,
        mulhsu,
        div,
        divw,
        divu,
        rem,
        remw,
        remu,
        remuw
    } _mdu;
    typedef enum logic [
    `WDEF(`MICOP_WIDTH)
    ] {
        lb  = 5'b0_1000,
        lh,
        lw,
        ld,
        lbu = 5'b1_0000,
        lhu,
        lwu
    } _ldu;
    typedef enum logic [
    `WDEF(`MICOP_WIDTH)
    ] {
        sb = 5'b0_1000,
        sh,
        sw,
        sd
    } _stu;
    typedef union packed {
        logic [`WDEF(`MICOP_WIDTH)] bits;
        _alu alu_op;
        _scu scu_op;
        _bru bru_op;
        _mdu mdu_op;
        _ldu ldu_op;
        _stu stu_op;
    } _u;
endpackage



`endif
