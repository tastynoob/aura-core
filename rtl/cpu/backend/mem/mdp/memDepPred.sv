


`include "backend_define.svh"





module memDepPred (
    input wire clk,
    input wire rst,

    input wire i_stall,

    // insert new inst
    // rename stage, lookup SSIT
    input wire[`WDEF(`RENAME_WIDTH)] i_lookup_ssit_vld,
    input wire[`WDEF(`MEMDEP_FOLDPC_WIDTH)] i_foldpc[`RENAME_WIDTH],

    // dispatch stage check inst dep and insert store
    input wire[`WDEF(`RENAME_WIDTH)] i_insert_store,
    input robIdx_t i_allocated_robIdx[`RENAME_WIDTH],
    output wire[`WDEF(`RENAME_WIDTH)] o_shouldwait,
    output robIdx_t o_dep_robIdx[`RENAME_WIDTH],

    // store issued
    input wire i_store_issued[`STORE_ISSUE_WIDTH],
    input wire[`WDEF(`MEMDEP_FOLDPC_WIDTH)] i_issue_foldpc[`STORE_ISSUE_WIDTH],
    input robIdx_t i_store_robIdx[`STORE_ISSUE_WIDTH],

    // violation update
    input wire i_violation,
    input wire[`WDEF(`MEMDEP_FOLDPC_WIDTH)] i_vio_store_foldpc,
    input wire[`WDEF(`MEMDEP_FOLDPC_WIDTH)] i_vio_load_foldpc
);


`ifdef ENABLE_MEMPRED
    StoreSet
    #(
        .SSIT_SIZE ( `SSIT_SIZE ),
        .LFST_SIZE ( `LFST_SIZE )
    )
    u_StoreSet(
        .clk                ( clk                ),
        .rst                ( rst                ),
        .i_stall            ( i_stall            ),

        .i_lookup_ssit_vld  ( i_lookup_ssit_vld  ),
        .i_foldpc           ( i_foldpc           ),

        .i_insert_store     ( i_insert_store     ),
        .i_allocated_robIdx ( i_allocated_robIdx ),
        .o_shouldwait       ( o_shouldwait       ),
        .o_dep_robIdx       ( o_dep_robIdx       ),

        .i_store_issued     ( i_store_issued     ),
        .i_issue_foldpc     ( i_issue_foldpc     ),
        .i_store_robIdx     ( i_store_robIdx     ),

        .i_violation        ( i_violation        ),
        .i_vio_store_foldpc ( i_vio_store_foldpc ),
        .i_vio_load_foldpc  ( i_vio_load_foldpc  )
    );

`else
    assign o_shouldwait = 0;
`endif

endmodule

