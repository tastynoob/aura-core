`ifndef __DECODE_DEFINE_SVH__
`define __DECODE_DEFINE_SVH__

`include "core_define.svh"






//addi xn,xn,0  空指令

//32位指令开头
`define OPC_TYPE32        2'b11

//需要计算
//需要写rd
//alu_b位为imm
`define OPC_LUI         5'b01101 // rd = imm
`define OPC_AUIPC       5'b00101 // rd = pc + imm
/*****************************************************///无条件跳转
`define OPC_JAL         5'b11011 // rd = pc + 4; pc += imm
`define OPC_JALR        5'b11001 // rd = pc+4;pc= ( rs1 + imm ) & ~1;
/*****************************************************///branch
`define OPC_BRANCH      5'b11000
`define FUNC_BEQ        3'b000 // if(rs1 == rs2) pc += imm; => if(rs1-rs2=0)
`define FUNC_BNE        3'b001 // if(rs1 != rs2) pc += imm; => if(rs1-rs2)
`define FUNC_BLT        3'b100 // if(rs1 < rs2)             => if(rs1 < rs2)
`define FUNC_BGE        3'b101 // if(rs1 >= rs2) pc += imm; => if(!(rs1 < rs2))
`define FUNC_BLTU       3'b110 // if(rs1 <u rs2)            => if(rs1 <u rs2)
`define FUNC_BGEU       3'b111 // if(rs1 >=u rs2)           => if(!(rs1 <u rs2))
/*****************************************************///load加载
`define OPC_LOAD        5'b00000
`define FUNC_LB         3'b000
`define FUNC_LH         3'b001
`define FUNC_LW         3'b010
`define FUNC_LBU        3'b100
`define FUNC_LHU        3'b101
/*****************************************************///store储存
`define OPC_STORE       5'b01000
`define FUNC_SB         3'b000
`define FUNC_SH         3'b001
`define FUNC_SW         3'b010
/*****************************************************///imm立即数指令
`define OPC_OPIMM       5'b00100
`define FUNC_ADDI       3'b000
`define FUNC_SLTI       3'b010
`define FUNC_SLTIU      3'b011
`define FUNC_XORI       3'b100
`define FUNC_ORI        3'b110
`define FUNC_ANDI       3'b111
`define FUNC_SLLI       3'b001
//特殊变种
`define FUNC_SRLI_SRAI  3'b101
`define FUNC7_SRLI      7'b0000000
`define FUNC7_SRAI      7'b0100000
/*****************************************************///op寄存器指令
`define OPC_OP          5'b01100
`define FUNC_ADD_SUB    3'b000
`define FUNC7_ADD       7'b0000000
`define FUNC7_SUB       7'b0100000
`define FUNC_SLL        3'b001
`define FUNC_SLT        3'b010
`define FUNC_SLTU       3'b011
`define FUNC_XOR        3'b100
`define FUNC_SRL_SRA    3'b101
`define FUNC7_SRL       7'b0000000
`define FUNC7_SRA       7'b0100000
`define FUNC_OR         3'b110
`define FUNC_AND        3'b111
/*****************************************************///fence
`define OPC_FENCE       5'b00011
`define FUNC_FENCE      3'b000
`define FUNC_FENCEI     3'b001
/*****************************************************///system系统指令
`define OPC_SYSTEM      5'b11100
`define FUNC_ECALL_EBREAK 3'b000
`define FUNC12_ECALL    12'b000000000000
`define FUNC12_EBREAK   12'b000000000001
`define FUNC_CSRRW      3'b001 //rd = csr,csr = rs1
`define FUNC_CSRRS      3'b010 //rd = csr,csr = csr | rs1
`define FUNC_CSRRC      3'b011 //rd = csr,csr = csr & ~rs1
`define FUNC_CSRRWI     3'b101 //rd = csr,csr = zimm
`define FUNC_CSRRSI     3'b110 //rd = csr,csr = csr | zimm
`define FUNC_CSRRCI     3'b111 //rd = csr,csr = csr & ~zimm,
/*****************************************************///rv64m extension
`define OPC_64IM         5'b01110

package Fu_t;
    typedef enum logic[`WDEF(5)] {
        none=0,
        alu,
        mdu,
        ldu,
        stu,
        misc,
        mv,//used fot move elim
        nop//nop
    } _;
endpackage

package MicOp_t;
`define MICOP_WIDTH 5
    const int none = 0;
    typedef enum logic[`WDEF(`MICOP_WIDTH)] {
        //arithmetic
        lui = 5'b01_000,
        add,
        sub,
        addw,
        subw,
        //shift
        sll = 5'b10_000,
        srl,
        sra,
        sllw,
        srlw,
        sraw,
        //logical
        _xor = 5'b11_000,
        _or,
        _and,
        slt, // dst = (src1 - src2)[-1]
        sltu // dst = (src1 - src2)[-1] == src1[-1]
    } _alu;
    typedef enum logic[`WDEF(`MICOP_WIDTH)]{
        mul = 5'b01_000,
        mulw,
        mulh,
        mulhu,
        mulhsu,
        div = 5'b10_000,
        diw,
        divu,
        rem,
        remw,
        remu,
        remuw
    }_mdu;
    typedef enum logic[`WDEF(`MICOP_WIDTH)]{
        lb = 5'b01_000,
        lbu,
        lh,
        lhu,
        lw,
        lwu,
        ld
    }_ldu;
    typedef enum logic[`WDEF(`MICOP_WIDTH)]{
        sb = 5'b01_000,
        sh,
        sw,
        sd
    }_stu;
    typedef enum logic[`WDEF(`MICOP_WIDTH)]{
        auipc,
        //direct branch
        jal,
        jalr,
        //conditional branch
        beq = 5'b01_000,
        bne,
        blt,
        bge,
        bltu,
        bgeu,
        //csr
        csrrc,
        csrrs,
        csrrw,
        //compressed branch(used for calc takenpc)
        cbeqz,
        cbnez
    }_misc;
    typedef union packed{
        logic[`WDEF(`MICOP_WIDTH)] bits;
        _alu alu_op;
        _mdu mdu_op;
        _ldu ldu_op;
        _stu stu_op;
        _misc misc_op;
    }_u;
endpackage


typedef struct packed {
    logic[`PCDEF] pc;
    // different inst use different format
    // NOTE: csr use imm20 = {3'b0,12'csrIdx,5'zimm}
    logic[`IMMDEF] imm20;
    logic need_serialize; // if is csr write, need to serialize pipeline
    logic rd_wen;
    ilrIdx_t rd;
    ilrIdx_t rs1; // if has no rs, it should be zero
    ilrIdx_t rs2;
    logic use_imm; //replace the rs2 source to imm
    //which dispQue should go
    logic[`WDEF(2)] dispQue_id;
    //which RS should go
    logic[`WDEF(2)] dispRS_id;
    logic ismv; //used for mov elim

    MicOp_t::_u micOp_type;
}decInfo_t;


`endif
