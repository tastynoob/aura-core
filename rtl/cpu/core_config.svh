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
`define IPHYREG_NUM 128
`define ROB_SIZE 64










`endif

