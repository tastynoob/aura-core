`include "core_define.svh"


//if one inst is mv
//should not dispatch to
//mark mv complete

// order in
module dispatch (
    input wire clk,
    input wire rst,

    // to rename
    output wire o_stall,

    input wire i_squash_vld,

    // from rename
    input wire[`WDEF(`RENAME_WIDTH)] i_enq_vld,
    input renameInfo_t i_enq_inst[`RENAME_WIDTH],

    // read immBuffer (clear when writeback)
    input irobIdx_t i_immB_read_dqIdx[`IMMBUFFER_READPORT_NUM],
    output imm_t o_immB_read_data[`IMMBUFFER_READPORT_NUM],
    input wire[`WDEF(`IMMBUFFER_CLEARPORT_NUM)] i_immB_clear_vld,
    input irobIdx_t i_immB_clear_dqIdx[`IMMBUFFER_CLEARPORT_NUM],

    // from/to rob
    input wire i_can_insert_rob,
    output wire o_insert_rob_vld,
    output wire[`WDEF(`RENAME_WIDTH)] o_insert_rob_req,
    output wire[`WDEF(`RENAME_WIDTH)] o_insert_rob_ismv,//if ismv, mark mv is finished
    output ROBEntry_t o_new_robEntry[`RENAME_WIDTH],
    output ftqOffset_t o_new_robEntry_ftqOffset[`RENAME_WIDTH],
    input robIdx_t i_alloc_robIdx[`RENAME_WIDTH],
    // if frontend or decode has except
    output wire o_exceptwb_vld,
    output exceptwbInfo_t o_exceptwb_info,

    // to exeBlock
    // TODO: we need to set the busytable

    // to int block
    input wire i_intBlock_stall,
    output wire[`WDEF(`INTDQ_DISP_WID)] o_intDQ_deq_vld,
    output intDQEntry_t o_intDQ_deq_info[`INTDQ_DISP_WID]

    // to mem block


);
    genvar i;


    //alloc immBubbfer id
    wire[`WDEF(`RENAME_WIDTH)] use_imm_vec;
    irobIdx_t irob_alloc_idx[`RENAME_WIDTH];// alloced immBuffer id
    wire[`IMMDEF] imm_vec[`RENAME_WIDTH];

    wire can_insert_intDQ;
    wire can_insert_memDQ = 1;
    wire can_insert_immBuffer;
    // only when can_dispatch is true
    wire can_dispatch = i_can_insert_rob && can_insert_intDQ && can_insert_memDQ && can_insert_immBuffer;

    logic[`WDEF(`RENAME_WIDTH)] insert_rob_vld;
    logic[`WDEF(`RENAME_WIDTH)] insert_intDQ_vld;
    logic[`WDEF(`RENAME_WIDTH)] insert_memDQ_vld;
    intDQEntry_t new_intDQEntry[`RENAME_WIDTH];

    rv_trap_t::exception oldest_except;

    // new rob entry
    assign insert_rob_vld = i_enq_vld;
    generate
        for(i=0;i<`RENAME_WIDTH;i=i+1) begin:gen_for
            // new intDQ entry, skip mv
            assign insert_intDQ_vld[i] = i_enq_vld[i] && (i_enq_inst[i].dispQue_id == `INTBLOCK_ID) && (!i_enq_inst[i].ismv);
            // new memDQ entry
            assign insert_memDQ_vld[i] = i_enq_vld[i] && (i_enq_inst[i].dispQue_id == `MEMBLOCK_ID);

            assign o_insert_rob_ismv[i] = i_enq_inst[i].ismv;
            assign use_imm_vec[i] = i_enq_vld[i] && i_enq_inst[i].use_imm;
            assign imm_vec[i] = i_enq_inst[i].imm20;
            assign o_new_robEntry[i] =
            '{
                ftq_idx         : i_enq_inst[i].ftq_idx,
                isRVC           : i_enq_inst[i].isRVC,
                ismv            : i_enq_inst[i].ismv,
                has_rd          : i_enq_inst[i].rd_wen,
                ilrd_idx        : i_enq_inst[i].ilrd_idx,
                iprd_idx        : i_enq_inst[i].iprd_idx,
                prev_iprd_idx   : i_enq_inst[i].prev_iprd_idx
            };
            assign o_new_robEntry_ftqOffset[i] = i_enq_inst[i].ftqOffset;
            assign new_intDQEntry[i] =
            '{
                ftq_idx    : i_enq_inst[i].ftq_idx,
                rob_idx    : i_alloc_robIdx[i],
                irob_idx   : irob_alloc_idx[i],
                rd_wen     : i_enq_inst[i].rd_wen,
                iprd_idx   : i_enq_inst[i].iprd_idx,
                iprs_idx   : i_enq_inst[i].iprs_idx,
                use_imm    : i_enq_inst[i].use_imm,
                issueQue_id  : i_enq_inst[i].issueQue_id,
                micOp_type : i_enq_inst[i].micOp_type
            };
        end
    endgenerate
    always_comb begin
        int ca;
        oldest_except = i_enq_inst[`RENAME_WIDTH-1].except;
        for(ca=`RENAME_WIDTH-1;ca>=0;ca=ca-1) begin
            if (i_enq_vld[ca] && i_enq_inst[ca].has_except) begin
                oldest_except = i_enq_inst[ca].except;
            end
        end
    end
    assign o_insert_rob_vld = can_dispatch;
    assign o_insert_rob_req = insert_rob_vld;
    assign o_stall = i_enq_vld[0] ? (!can_dispatch) : 0;


/****************************************************************************************************/
// frontend exception process ( instIllegal/pcUnaligned )
// delay it by one cycle
/****************************************************************************************************/

    reg[`WDEF(`RENAME_WIDTH)] has_except;
    exceptwbInfo_t oldest_except_info;
    always_ff @( posedge clk ) begin
        int fa;
        if(rst) begin
            has_except <= 0;
        end
        else begin
            for(fa=`RENAME_WIDTH-1;fa>=0;fa=fa-1) begin
                has_except[fa] <= insert_rob_vld[fa] && i_enq_inst[fa].has_except && can_dispatch;
            end
            oldest_except_info <= '{
                rob_idx : i_alloc_robIdx[fa],
                except_type: oldest_except
            };
        end
    end

    assign o_exceptwb_vld = (|has_except);
    assign o_exceptwb_info = oldest_except_info;

    `ORDER_CHECK(insert_rob_vld);


/****************************************************************************************************/
// int block
/****************************************************************************************************/

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
        .i_deq_req  ( i_intBlock_stall ? 0 : intDQ_deq_feedback  ),
        .o_deq_data ( o_intDQ_deq_info )
    );
    assign o_intDQ_deq_vld = intDQ_deq_feedback;


/****************************************************************************************************/
// mem block
/****************************************************************************************************/



/****************************************************************************************************/
// imm reorder buffer
/****************************************************************************************************/
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
        .dtype          ( imm_t  )
    )
    u_immBuffer(
        .clk            ( clk   ),
        .rst            ( rst || i_squash_vld   ),

        .o_can_enq      ( can_insert_immBuffer  ),
        .i_enq_vld      ( can_dispatch  ),
        .i_enq_req      ( use_imm_vec   ),
        .i_enq_data     ( imm_vec       ),
        .o_alloc_id     ( irob_alloc_idx   ),

        .i_read_dqIdx   ( i_immB_read_dqIdx     ),
        .o_read_data    ( o_immB_read_data      ),

        .i_clear_vld    ( i_immB_clear_vld      ),
        .i_clear_dqIdx  ( i_immB_clear_dqIdx    )
    );

endmodule








