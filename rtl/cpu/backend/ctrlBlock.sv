
`include "core_define.svh"



// decode -> rename -> rob

module ctrlBlock (
    input wire clk,
    input wire rst,

    // from/ fetch
    output wire o_stall,
    input wire[`WDEF(`FETCH_WIDTH)] i_inst_vld,
    input fetchEntry_t i_inst[`FETCH_WIDTH],

    // read immBuffer (clear when writeback)
    input irobIdx_t i_immB_read_dqIdx[`IMMBUFFER_READPORT_NUM],
    output imm_t o_immB_read_data[`IMMBUFFER_READPORT_NUM],
    input wire[`WDEF(`IMMBUFFER_CLEARPORT_NUM)] i_immB_clear_vld,
    input irobIdx_t i_immB_clear_dqIdx[`IMMBUFFER_CLEARPORT_NUM],

    // read ftqOffset (exu read from rob)
    input wire[`WDEF($clog2(`ROB_SIZE))] i_read_ftqOffset_idx[`BRU_NUM],
    output ftqOffset_t o_read_ftqOffset_data[`BRU_NUM],

    // write back, from exu
    // common writeback
    input wire[`WDEF(`WBPORT_NUM)] i_wb_vld,
    input valwbInfo_t i_valwb_info[`WBPORT_NUM],
    // branch writeback (branch taken or mispred)
    input wire i_branchwb_vld,
    input branchwbInfo_t i_branchwb_info,
    // except writeback
    input wire i_exceptwb_vld,
    input exceptwbInfo_t i_exceptwb_info,

    // to exe block
    // to intBlock
    input wire i_intBlock_stall,
    output wire[`WDEF(`INTDQ_DISP_WID)] o_intDQ_deq_vld,
    output intDQEntry_t o_intDQ_deq_info[`INTDQ_DISP_WID],

    // notify ftq and storeQue
    output wire o_commit_vld,
    output wire[`WDEF($clog2(`ROB_SIZE))] o_commit_rob_idx,
    output ftqIdx_t o_commit_ftq_idx,

    // read ftq startAddress from ftq
    output ftqIdx_t o_read_ftqIdx,
    input wire[`XDEF] i_read_ftqStartAddr,

    output wire o_squash_vld,
    output squashInfo_t o_squashInfo

);
    genvar i;
    int j;

/****************************************************************************************************/
// fetch inst buffer
//
/****************************************************************************************************/
    fetchEntry_t toDecode_data[`DECODE_WIDTH];
    wire[`WDEF(`DECODE_WIDTH)] toDecode_inst_vld;
    wire[`WDEF(`DECODE_WIDTH)] toInstBuffer_deq_req;
    wire can_insert_instBuffer;

    fifo
    #(
        .dtype       ( fetchEntry_t       ),
        .INPORT_NUM  ( `FETCH_WIDTH  ),
        .OUTPORT_NUM ( `DECODE_WIDTH ),
        .DEPTH       ( 8       ),
        .USE_INIT    ( 0    )
    )
    fetch_inst_buffer(
        .clk         ( clk  ),
        .rst         ( rst  ),
        .i_flush     ( o_squash_vld   ),

        .o_can_enq  ( can_insert_instBuffer ),
        .i_enq_vld   ( can_insert_instBuffer ),
        .i_enq_req   ( i_inst_vld  ),
        .i_enq_data  ( i_inst   ),

        .o_can_deq  ( toDecode_inst_vld  ),
        .i_deq_req  ( toInstBuffer_deq_req  ),
        .o_deq_data ( toDecode_data   )
    );

    assign o_stall = !can_insert_instBuffer;

/****************************************************************************************************/
// decode
//
/****************************************************************************************************/

    wire[`WDEF(`DECODE_WIDTH)] toRename_vld;
    decInfo_t toRename_decInfo[`DECODE_WIDTH];
    wire toDecode_stall;

    decode u_decode(
        .clk           ( clk           ),
        .rst           ( rst           ),

        .i_stall       ( toDecode_stall       ),
        .i_squash_vld  ( o_squash_vld  ),

        .o_can_deq     ( toInstBuffer_deq_req     ),
        .i_inst_vld    ( toDecode_inst_vld    ),
        .i_inst        ( toDecode_data        ),

        .o_decinfo_vld ( toRename_vld ),
        .o_decinfo     ( toRename_decInfo     )
    );




/****************************************************************************************************/
// rename
//
/****************************************************************************************************/
    wire toRename_stall;
    wire[`WDEF(`RENAME_WIDTH)] toDIspatch_vld;
    renameInfo_t toDIspatch_renameInfo[`RENAME_WIDTH];

    wire[`WDEF(`COMMIT_WIDTH)] toRename_commit;
    renameCommitInfo_t toRename_commitInfo[`COMMIT_WIDTH];

    rename u_rename(
        .rst           ( rst           ),
        .clk           ( clk           ),

        .o_stall       ( toDecode_stall       ),
        .i_stall       ( toRename_stall       ),

        .i_squash_vld  ( o_squash_vld  ),

        .i_commit_vld  ( toRename_commit  ),
        .i_commitInfo  ( toRename_commitInfo  ),

        .i_decinfo_vld ( toRename_vld ),
        .i_decinfo     ( toRename_decInfo     ),

        .o_rename_vld  ( toDIspatch_vld  ),
        .o_renameInfo  ( toDIspatch_renameInfo  )
    );


/****************************************************************************************************/
// dispatch and rob
//
/****************************************************************************************************/

    wire toDispatch_can_insert;
    wire toROB_insert_vld;
    wire[`WDEF(`RENAME_WIDTH)] toROB_insert_req, toROB_insert_ismv;
    ROBEntry_t toROB_new_entry[`RENAME_WIDTH];
    ftqOffset_t toROB_new_enrty_ftqOffset[`RENAME_WIDTH];
    robIdx_t toDispatch_alloc_robIdx[`RENAME_WIDTH];

    wire toROB_disp_exceptwb_vld;
    exceptwbInfo_t toROB_disp_exceptwb_info;

    dispatch u_dispatch(
        .clk                      ( clk                 ),
        .rst                      ( rst || o_squash_vld ),

        .o_stall                  ( toRename_stall  ),
        .i_squash_vld             ( o_squash_vld    ),

        .i_enq_vld                ( toDIspatch_vld          ),
        .i_enq_inst               ( toDIspatch_renameInfo   ),

        .i_immB_read_dqIdx        ( i_immB_read_dqIdx       ),
        .o_immB_read_data         ( o_immB_read_data        ),
        .i_immB_clear_vld         ( i_immB_clear_vld         ),
        .i_immB_clear_dqIdx       ( i_immB_clear_dqIdx      ),

        .i_can_insert_rob         ( toDispatch_can_insert   ),
        .o_insert_rob_vld         ( toROB_insert_vld        ),
        .o_insert_rob_req         ( toROB_insert_req        ),
        .o_insert_rob_ismv        ( toROB_insert_ismv       ),
        .o_new_robEntry           ( toROB_new_entry         ),
        .o_new_robEntry_ftqOffset ( toROB_new_enrty_ftqOffset ),
        .i_alloc_robIdx           ( toDispatch_alloc_robIdx   ),

        .o_exceptwb_vld           ( toROB_disp_exceptwb_vld         ),
        .o_exceptwb_info          ( toROB_disp_exceptwb_info         ),
        // to intBlock
        .i_intBlock_stall         ( i_intBlock_stall          ),
        .o_intDQ_deq_vld          ( o_intDQ_deq_vld         ),
        .o_intDQ_deq_info         ( o_intDQ_deq_info         )
    );

    ROB u_ROB(
        .clk                   (clk                   ),
        .rst                   (rst                   ),

        .i_csr_pack            (            ),
        .o_csr_pack            (            ),

        .o_can_enq             ( toDispatch_can_insert             ),
        .i_enq_vld             ( toROB_insert_vld             ),
        .i_enq_req             ( toROB_insert_req             ),
        .i_insert_rob_ismv     ( toROB_insert_ismv     ),
        .i_new_entry           ( toROB_new_entry           ),
        .i_new_entry_ftqOffset ( toROB_new_enrty_ftqOffset ),
        .o_alloc_robIdx        ( toDispatch_alloc_robIdx        ),

        .i_read_ftqOffset_idx  ( i_read_ftqOffset_idx ),
        .o_read_ftqOffset_data ( o_read_ftqOffset_data ),

        .i_wb_vld              ( i_wb_vld             ),
        .i_valwb_info              ( i_valwb_info             ),
        .i_branchwb_vld        ( i_branchwb_vld       ),
        .i_branchwb_info       ( i_branchwb_info      ),
        .i_exceptwb_vld        ( i_exceptwb_vld || toROB_disp_exceptwb_vld ),
        .i_exceptwb_info       ( i_exceptwb_vld ? i_exceptwb_info : toROB_disp_exceptwb_info ),

        .o_commit_vld          ( o_commit_vld         ),
        .o_commit_rob_idx       ( o_commit_rob_idx  ),
        .o_commit_ftq_idx      ( o_commit_ftq_idx  ),

        .o_rename_commit       ( toRename_commit      ),
        .o_rename_commitInfo   ( toRename_commitInfo  ),

        .o_read_ftqIdx             ( o_read_ftqIdx             ),
        .i_read_ftqStartAddr    ( i_read_ftqStartAddr   ),

        .o_squash_vld          ( o_squash_vld         ),
        .o_squashInfo          ( o_squashInfo         )
    );




endmodule
