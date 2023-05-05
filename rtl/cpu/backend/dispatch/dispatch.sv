`include "dispatch_define.svh"
`include "rename_define.svh"


//if one inst is mv
//should not dispatch to
//mark mv complete


module dispatch (
    input wire clk,
    input wire rst,

    output wire o_can_enq,
    input wire[`WDEF(`RENAME_WIDTH)] i_enq_vld,
    input renameInfo_t i_enq_inst[`RENAME_WIDTH],

    // to int block
    output wire o_dispInt_vld,
    output intDQEntry_t o_disqInt_info

    // to mem block


);
    integer a;

    wire[`WDEF(`RENAME_WIDTH)] insert_intDQ_vld;
    wire[`WDEF(`RENAME_WIDTH)] insert_memDQ_vld;
    always_comb begin
        for(a=0;a<`RENAME_WIDTH;a=a+1) begin
            insert_intDQ_vld[a] = false;
            insert_memDQ_vld[a] = false;
            if (i_enq_vld[a]) begin
                if (i_enq_inst[a].disqQue_id == `INTBLOCK_ID) begin
                    insert_intDQ_vld[a] = true;
                end
                else if (i_enq_inst[a].disqQue_id == `MEMBLOCK_ID) begin
                    insert_memDQ_vld[a] = true;
                end
            end
        end
    end
    //intblock

    reorder
    #(
        .dtype (renameInfo_t ),
        .NUM   (`RENAME_WIDTH   )
    )
    u_reorder_0(
        .i_data_vld      (insert_intDQ_vld      ),
        .i_datas         (i_enq_inst         ),
        .o_data_vld      (o_data_vld      ),
        .o_reorder_datas (o_reorder_datas )
    );
    fifo
    #(
        .dtype       ( intDQEntry_t    ),
        .INPORT_NUM  ( `RENAME_WIDTH  ),
        .OUTPORT_NUM ( `RENAME_WIDTH ),
        .DEPTH       ( 16       ),
        .USE_INIT    ( 0    )
    )
    u_int_dispQue(
        .init_data   (),
        .clk         (clk         ),
        .rst         (rst         ),
        .i_flush     (i_flush     ),

        .o_can_write (o_can_write ),
        .i_data_wen  (i_data_wen  ),
        .i_data_wr   (i_data_wr   ),

        .o_can_read  (o_can_read  ),
        .i_data_ren  (i_data_ren  ),
        .o_data_rd   (o_data_rd   )
    );
    //memblock
    reorder
    #(
        .dtype (renameInfo_t ),
        .NUM   (`RENAME_WIDTH   )
    )
    u_reorder_1(
        .i_data_vld      (insert_memDQ_vld      ),
        .i_datas         (i_enq_inst         ),
        .o_data_vld      (o_data_vld      ),
        .o_reorder_datas (o_reorder_datas )
    );

    //branch buffer
    dataQue
    #(
        .DEPTH        (DEPTH        ),
        .INPORT_NUM   (INPORT_NUM   ),
        .READPORT_NUM (READPORT_NUM ),
        .CLEAR_WID    (CLEAR_WID    ),
        .dtype        (dtype        ),
        .QUE_TYPE     (QUE_TYPE     )
    )
    u_branchBuffer(
        .clk          (clk          ),
        .rst          (rst          ),
        .o_can_enq    (o_can_enq    ),
        .i_enq_req    (i_enq_req    ),
        .i_enq_data   (i_enq_data   ),
        .o_alloc_id   (o_alloc_id   ),
        .i_read_dqIdx (i_read_dqIdx ),
        .o_read_data  (o_read_data  ),
        .i_wb_vld     (i_wb_vld     ),
        .i_wb_dqIdx   (i_wb_dqIdx   )
    );

    //imm Que
    dataQue
    #(
        .DEPTH        (DEPTH        ),
        .INPORT_NUM   (INPORT_NUM   ),
        .READPORT_NUM (READPORT_NUM ),
        .CLEAR_WID    (CLEAR_WID    ),
        .dtype        (dtype        ),
        .QUE_TYPE     (QUE_TYPE     )
    )
    u_immBuffer(
        .clk          (clk          ),
        .rst          (rst          ),
        .o_can_enq    (o_can_enq    ),
        .i_enq_req    (i_enq_req    ),
        .i_enq_data   (i_enq_data   ),
        .o_alloc_id   (o_alloc_id   ),
        .i_read_dqIdx (i_read_dqIdx ),
        .o_read_data  (o_read_data  ),
        .i_wb_vld     (i_wb_vld     ),
        .i_wb_dqIdx   (i_wb_dqIdx   )
    );


endmodule








