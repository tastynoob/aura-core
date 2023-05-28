`include "core_define.svh"


//if one inst is mv
//should not dispatch to
//mark mv complete

// order in
module dispatch (
    input wire clk,
    input wire rst,
    // squash
    input wire i_squash_vld,
    input squashInfo_t i_squashInfo,
    // to rename
    output wire o_stall,

    // from rename
    output wire o_can_enq,
    input wire[`WDEF(`RENAME_WIDTH)] i_enq_vld,
    input renameInfo_t i_enq_inst[`RENAME_WIDTH],

    // read immBuffer
    input immBIdx_t i_immB_read_dqIdx[`IMMBUFFER_READPORT_NUM],
    output dtype o_immB_read_data[`IMMBUFFER_READPORT_NUM],
    input wire[`WDEF(`IMMBUFFER_CLEARPORT_NUM)] i_immB_clear_vld,
    input immBIdx_t i_immB_clear_dqIdx[`IMMBUFFER_CLEARPORT_NUM],

    // read and writeback branchBuffer
    input immBIdx_t i_branchB_read_dqIdx[`BRANCHBUFFER_READPORT_NUM],
    output dtype o_branchB_read_data[`BRANCHBUFFER_READPORT_NUM],
    input wire[`WDEF(`BRANCHBUFFER_CLEARPORT_NUM)] i_branchB_clear_vld,
    input immBIdx_t i_branchB_clear_dqIdx[`BRANCHBUFFER_CLEARPORT_NUM],
    // writeback (only for branchBuffer)
    input wire[`WDEF(`BRANCHBUFFER_WBPORT_NUM)] i_branchB_wb_vld,
    input wire[`WDEF($clog2(DEPTH)-1)] i_branchB_wb_dqIdx[`BRANCHBUFFER_WBPORT_NUM],
    input wire[`XDEF] i_branchB_wb_npc[`BRANCHBUFFER_WBPORT_NUM],

    // from rob/commit
    input wire i_can_insert_rob,
    output wire[`WDEF(`RENAME_WIDTH)] o_insert_rob_vld,
    output ROBEntry_t o_new_robEntry[`RENAME_WIDTH],
    input robIdx_t i_alloc_robIdx[`RENAME_WIDTH],

    // to int block
    input wire i_intBlock_stall,
    output wire[`WDEF(`INTDQ_DISP_WID)] o_intDQ_deq_vld,
    output intDQEntry_t o_intDQ_deq_info[`INTDQ_DISP_WID]

    // to mem block


);
    genvar i;
    integer a;

    //alloc immBubbfer id
    wire[`WDEF(`RENAME_WIDTH)] use_imm_vec;
    immBIdx_t immBIdx_vec[`RENAME_WIDTH];// alloced immBuffer id
    wire[`IMMDEF] imm_vec[`RENAME_WIDTH];
    // alloced branchBuffer id
    wire[`WDEF(`RENAME_WIDTH)] use_pc_vec;
    branchBIdx_t branchBIdx_vec[`RENAME_WIDTH];
    wire[`XDEF] branch_pc_vec[`RENAME_WIDTH];

    always_comb begin
        for (a=0;a<`RENAME_WIDTH;a=a+1) begin
            use_imm_vec[i] = i_enq_vld[i] && i_enq_inst[i].use_imm;
            imm_vec[i] = i_enq_inst[i].imm20;
            //auipc also need pc, but has no npc
            use_pc_vec[i] = i_enq_vld[i] &&
            i_enq_inst[i].dispQue_id == `INTBLOCK_ID &&
            i_enq_inst[i].dispRS_id == `ALUIQ_ID &&
            (i_enq_inst[i].micOp_type >= MicOp_t::auipc && i_enq_inst[i].micOp_type <= MicOp_t::bgeu);
        end
    end

    wire can_insert_intDQ;
    wire can_insert_memDQ;
    wire can_insert_branchBuffer;
    wire can_insert_immBuffer;
    // only when can_dispatch is true
    wire can_dispatch = i_can_insert_rob && can_insert_intDQ && can_insert_memDQ && can_insert_immBuffer && can_insert_branchBuffer;

    wire[`WDEF(`RENAME_WIDTH)] insert_rob_vld;
    wire[`WDEF(`RENAME_WIDTH)] insert_intDQ_vld;
    wire[`WDEF(`RENAME_WIDTH)] insert_memDQ_vld;
    intDQEntry_t new_intDQEntry[`RENAME_WIDTH];
    always_comb begin
        for(a=0;a<`RENAME_WIDTH;a=a+1) begin
            insert_rob_vld[a] = false;
            insert_intDQ_vld[a] = false;
            insert_memDQ_vld[a] = false;
            if (i_enq_vld[a]) begin
                // new rob entry
                insert_rob_vld[a] = true;
                o_new_robEntry[a] =
                '{
                    has_rd          : i_enq_inst[a].rd_wen,
                    ilrd_idx        : i_enq_inst[a].ilrd_idx,
                    iprd_idx        : i_enq_inst[a].iprd_idx,
                    prev_iprd_idx   : i_enq_inst[a].prev_iprd_idx,
                    branchBIdx      : branchBIdx_vec[a]
                };
                // new intDQ entry
                if (i_enq_inst[a].disqQue_id == `INTBLOCK_ID && (!i_enq_inst[a].ismv)) begin
                    insert_intDQ_vld[a] = true;
                    new_intDQEntry[a] =
                    '{
                        rd_wen     : i_enq_inst[a].rd_wen,
                        iprd_idx   : i_enq_inst[a].iprd_idx,
                        iprs_idx   : i_enq_inst[a].iprs_idx,
                        use_imm    : i_enq_inst[a].use_imm,
                        dispRS_id  : i_enq_inst[a].dispRS_id,
                        robIdx     : i_alloc_robIdx[a],
                        immBIdx    : immBIdx_vec[a],
                        branchBIdx : branchBIdx_vec[a],
                        micOp_type : i_enq_inst[a].micOp_type
                    };
                end
                // new memDQ entry
                else if (i_enq_inst[a].disqQue_id == `MEMBLOCK_ID) begin
                    insert_memDQ_vld[a] = true;
                    //TODO:new_memDQEntry
                end
            end
        end
    end
    assign o_insert_rob_vld = insert_rob_vld;
    `ORDER_CHECK(insert_rob_vld);

/******************** int block ********************/

    wire[`WDEF(`INTDQ_DISP_WID)] intDQ_deq_feedback;
    dispQue
    #(
        .DEPTH       ( 16       ),
        .INPORT_NUM  ( `RENAME_WIDTH  ),
        .OUTPORT_NUM ( `INTDQ_DISP_WID ),
        .dtype       ( intDQEntry_t       )
    )
    u_int_dispQue(
        .clk        ( clk        ),
        .rst        ( rst        ),
        .i_flush    ( i_squash_vld    ),

        .o_can_enq  ( can_insert_intDQ    ),
        .i_enq_vld  ( can_dispatch        ),
        .i_enq_req  ( insert_intDQ_vld    ),
        .i_enq_data ( new_intDQEntry      ),

        .o_can_deq  ( intDQ_deq_feedback  ),
        .i_enq_req  ( i_intBlock_stall ? 0 : intDQ_deq_feedback  ),
        .o_deq_data ( o_intDQ_deq_info )
    );
    assign o_intDQ_deq_vld = intDQ_deq_feedback;


/******************** mem block ********************/



/******************** imm buffer ********************/
    //DESIGN:
    //when this inst is completed (writeback finished)
    //this entry can be freed
    dataQue
    #(
        .DEPTH          ( `IMMBUFFER_SIZE ),
        .INPORT_NUM     ( `RENAME_WIDTH   ),
        .READPORT_NUM   ( `IMMBUFFER_READPORT_NUM   ),
        .CLEARPORT_NUM  ( `IMMBUFFER_CLEARPORT_NUM  ),
        .COMMIT_WID     ( `IMMBUFFER_COMMIT_WID     ),
        .dtype          ( logic[`IMMDEF]  )
    )
    u_immBuffer(
        .clk            ( clk   ),
        .rst            ( rst || i_squash_vld   ),

        .o_can_enq      ( can_insert_immBuffer  ),
        .i_enq_vld      ( can_dispatch  ),
        .i_enq_req      ( use_imm_vec   ),
        .i_enq_data     ( imm_vec       ),
        .o_alloc_id     ( immBIdx_vec   ),

        .i_read_dqIdx   ( i_immB_read_dqIdx     ),
        .o_read_data    ( o_immB_read_data      ),

        .i_clear_vld    ( i_immB_clear_vld      ),
        .i_clear_dqIdx  ( i_immB_clear_dqIdx    )
    );


/******************** branch buffer ********************/
    // DESIGN:
    // only when branch commit finished
    // this entry can be freed
    // why?
    // because we need branchInst's pc o update bpu

    // branchBuffer must write and save the npc from writeback

    pc_and_npc_t pc_and_npc[`RENAME_WIDTH];
    generate
        for (i=0;i<`RENAME_WIDTH;i=i+1) begin : gen_for
            assign pc_and_npc[i] = '{pc:i_enq_inst[i].pc,npc:i_enq_inst[i].npc};
        end
    endgenerate

    dataQue
    #(
        .DEPTH          ( `BRANCHBUFFER_SIZE ),
        .INPORT_NUM     ( `RENAME_WIDTH ),
        .READPORT_NUM   ( `BRANCHBUFFER_READPORT_NUM  ),
        .CLEARPORT_NUM  ( `BRANCHBUFFER_CLEARPORT_NUM ),
        .WBPORT_NUM     ( `BRANCHBUFFER_WBPORT_NUM             ),// the num of bpu
        .COMMIT_WID     ( `BRANCHBUFFER_COMMIT_WID             ),
        .dtype          ( pc_and_npc_t  ),
        .ISBRANCHBUFFER ( 1             ) // only for branchBuffer
    )
    u_branchBuffer(
        .clk            ( clk           ),
        .rst            ( rst || i_squash_vld      ),

        .o_can_enq      ( can_insert_branchBuffer  ),
        .i_enq_vld      ( can_dispatch      ),
        .i_enq_req      ( use_pc_vec        ),
        .i_enq_data     ( pc_and_npc        ),
        .o_alloc_id     ( branchBIdx_vec    ),

        .i_read_dqIdx   ( i_branchB_read_dqIdx  ),
        .o_read_data    ( o_branchB_read_data   ),

        .i_clear_vld    ( i_branchB_clear_vld   ),
        .i_clear_dqIdx  ( i_branchB_clear_dqIdx ),

        .i_wb_vld       ( i_branchB_wb_vld      ),
        .i_wb_dqIdx     ( i_branchB_wb_dqIdx    ),
        .i_wb_npc       ( i_branchB_wb_npc      )
    );




endmodule








