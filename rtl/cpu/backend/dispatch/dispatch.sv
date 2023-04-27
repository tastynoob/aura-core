`include "dispatch_define.svh"
`include "rename_define.svh"


//if one inst is mv
//should not dispatch to
//mark mv complete


module dispatch (
    input wire clk,
    input wire rst,

    input wire i_enq_vld,
    input renameInfo_t i_enq_inst,
    input robIdx_t i_alloc_robIdx,
    input immBIdx_t i_alloc_immBIdx,
    input branchBIdx_t i_alloc_branchBIdx

    // to int block


    // to mem block


);



endmodule








