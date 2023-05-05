`ifndef __DISPATCH_DEFINE_SVH__
`define __DISPATCH_DEFINE_SVH__

`include "core_define.svh"
`include "decode_define.svh"


// TODO: we may need to implement pcbuffer and immbuffer

//dispatch queue type
`define DQ_INT 0
`define DQ_MEM 1


typedef struct {
    logic rd_wen;
    iprIdx_t rd;
    iprIdx_t rs[`NUMSRCS_INT];
    logic use_imm;
    logic[`WDEF(2)] dispRS_id;
    robIdx_t robIdx;
    immBIdx_t immBIdx;
    branchBIdx_t branchBIdx;
    MicOp_t::_u micOp_type;
} intDQEntry_t;





`endif
