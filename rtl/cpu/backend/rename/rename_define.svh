`ifndef __RENAME_DEFINE_SVH__
`define __RENAME_DEFINE_SVH__
`include "core_define.svh"
`include "decode_define.svh"

//move elim
//li x1,1
//li x2,1
//add x1,x1,x2
//add x2,x1,x2
//mv x2,x1
//add x1,x1,x2
//after rename
//li p1,1       ;p1:1
//li p2,1       ;p2:1
//add p3,p1,p2  ;p3:1
//add p4,p3,p2  ;p4:1
//mv p3,p3      ;p3:2
//add p5,p3,p4  ;p5:1



typedef struct packed {
    logic rd_wen;
    iprIdx_t rd;
    iprIdx_t rs1;
    iprIdx_t rs2;
    //which dispQue should go
    logic[`WDEF(2)] dispQue_id;
    //which RS should go
    logic[`WDEF(2)] dispRS_id;
    logic ismv; //used for mov elim
    MicOp_t::_u micOp_type;
} renameInfo_t;








`endif
