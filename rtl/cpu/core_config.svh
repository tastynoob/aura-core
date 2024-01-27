`ifndef __CORE_CONFIG_SVH__
`define __CORE_CONFIG_SVH__

`include "core_comm.svh"


`define FETCH_WIDTH `FTB_PREDICT_WIDTH/2

// decode rename
`define DECODE_WIDTH 4
`define RENAME_WIDTH `DECODE_WIDTH

// dispatch
`define INTDQ_DISP_WID 4
`define MEMDQ_DISP_WID 4

// immBuffer read port
`define IMMBUFFER_READPORT_NUM 4
`define IMMBUFFER_CLEARPORT_NUM 4
`define IMMBUFFER_COMMIT_WID 4


//used for dispatch into dispQue
`define INTBLOCK_ID 0
`define MEMBLOCK_ID 1
`define FLTBLOCK_ID 2
`define UNKOWNBLOCK_ID 3

`define ENABLE_MEMPRED 1

`define STORE_ISSUE_WIDTH 2

// issue
//used for dispQue into RS
`define ALUIQ_ID 0
`define BRUIQ_ID 1
`define MDUIQ_ID 2
`define SCUIQ_ID 3
`define LDUIQ_ID 4
`define STUIQ_ID 5


// execute and write back

`define ALU_NUM 4
`define MDU_NUM 2
`define BRU_NUM 2

`define LDU_NUM 2

`define STU_NUM 2

`define WBPORT_NUM 6


// commit
`define COMMIT_WIDTH 4


//int physical register num
//the int Inst needs at least 2 srcs
`define NUMSRCS_INT 2




`endif

