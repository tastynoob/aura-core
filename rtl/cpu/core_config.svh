`ifndef __CORE_CONFIG_SVH__
`define __CORE_CONFIG_SVH__
`include "base.svh"

`define XLEN 64
`define XLEN_64

`define FETCH_WIDTH 4
`define DECODE_WIDTH 4
`define RENAME_WIDTH `DECODE_WIDTH

`define DISP_TO_INT_BLOCK_PORTNUM 4
`define DISP_TO_MEM_BLOCK_PORTNUM 4


`define COMMIT_WIDTH 4

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



//used for dispatch into dispQue
`define INTBLOCK_ID 0
`define MEMBLOCK_ID 1
`define FLTBLOCK_ID 2
//used for dispQue into RS
`define ALUIQ_ID 0
`define MDUIQ_ID 1
`define MISCIQ_ID 2



`endif

