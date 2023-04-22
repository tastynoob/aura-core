`ifndef __CORE_CONFIG_SVH__
`define __CORE_CONFIG_SVH__
`include "base.svh"

`define XLEN 64
`define XLEN_64

`define DECODE_WIDTH 4
`define RENAME_WIDTH `DECODE_WIDTH
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


//used for dispatch into dispQue
`define INTBLOCK_ID 0
`define MEMBLOCK_ID 1
`define FLTBLOCK_ID 2
//used for dispQue into RS
`define ALURS_ID 0
`define MULRS_ID 1
`define DIVRS_ID 2
`define MISCRS_ID 3



`endif

