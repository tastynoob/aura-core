`ifndef __CORE_CONFIG_SVH__
`define __CORE_CONFIG_SVH__
`include "base.svh"

`define XLEN 64
`define XLEN_64


// branch predictor
// the fetch block max size is 64

`define FETCHBLOCK_MAX_INST 64 // byte
// actually pc = fetch start pc + (offset<<1)
`define FETCHBLOCK_OFFSET_WIDTH ($clog2(`FETCHBLOCK_MAX_INST) - 1)


// fetch

`define FSQ_SIZE 4

`define FETCH_WIDTH 4

// decode rename
`define DECODE_WIDTH 4
`define RENAME_WIDTH `DECODE_WIDTH

// dispatch
`define IMMBUFFER_SIZE 40
`define BRANCHBUFFER_SIZE 30
`define INTDQ_DISP_WID 4
`define MEMDQ_DISP_WID 4

// immBuffer read port
`define IMMBUFFER_READPORT_NUM 4
`define IMMBUFFER_CLEARPORT_NUM 4
`define IMMBUFFER_COMMIT_WID 4

// branchBuffer read port
// misc need 1 port
// commit need 2 port
`define BRANCHBUFFER_READPORT_NUM 3
`define BRANCHBUFFER_CLEARPORT_NUM 1
`define BRANCHBUFFER_WBPORT_NUM 1
`define BRANCHBUFFER_COMMIT_WID 4

`define DISP_TO_INT_BLOCK_PORTNUM 4
`define DISP_TO_MEM_BLOCK_PORTNUM 4

//used for dispatch into dispQue
`define INTBLOCK_ID 0
`define MEMBLOCK_ID 1
`define FLTBLOCK_ID 2
`define UNKOWNBLOCK_ID 3

// issue

//used for dispQue into RS
`define ALUIQ_ID 0
`define MDUIQ_ID 1
`define MISCIQ_ID 2

// execute and write back

`define ALU_NUM 3
`define MDU_NUM 2
`define MISC_NUM 1

`define WBPORT_NUM 6


// commit
`define COMMIT_WIDTH 4
`define ROB_SIZE 128


//int logic register index def
`define ILRIDX_DEF `WDEF($clog2(32))
//flt logic register index def
`define FLRIDX_DEF `ILRIDX_DEF
//xlen fast define
`define XDEF `WDEF(`XLEN)
//instruction fast define
`define IDEF `WDEF(32)
//commpressed instruction fast define
`define CIDEF `WDEF(16)

`define CSRIDX_DEF `WDEF(12)
`define PCDEF `WDEF(64)
`define IMMDEF `WDEF(20)

//int physical register num
`define IPHYREG_NUM 80
`define ROB_SIZE 128

//the int Inst needs at least 2 srcs
`define NUMSRCS_INT 2


`define INIT_PC 64'h8000000000000000











`endif

