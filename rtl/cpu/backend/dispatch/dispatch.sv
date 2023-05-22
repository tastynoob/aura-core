`include "core_define.svh"


//if one inst is mv
//should not dispatch to
//mark mv complete

// order in
module dispatch (
    input wire clk,
    input wire rst,
    //squash
    input wire i_squash_vld,
    input squashInfo_t i_squashInfo,

    //from rename
    output wire o_can_enq,
    input wire[`WDEF(`RENAME_WIDTH)] i_enq_vld,
    input renameInfo_t i_enq_inst[`RENAME_WIDTH],

    // to int block
    output wire o_dispInt_vld,
    output intDQEntry_t o_disqInt_info

    // to mem block


);
    genvar i;
    integer a;

    //dispatch alloc pc
    reg[`XDEF] spec_disp_pc_base;
    wire[`SDEF(`RENAME_WIDTH * 4)] sepc_disp_pc_acc[`RENAME_WIDTH];
    wire[`XDEF] spec_disp_pc_vec[`RENAME_WIDTH];

    always_ff @( posedge clk ) begin
        if (rst==true) begin
            spec_disp_pc_base <= `INIT_PC;
        end
        else if (i_squash_vld) begin
            spec_disp_pc_base <= i_squashInfo.arch_pc;
        end
        else begin
            spec_disp_pc_base += sepc_disp_pc_acc[`RENAME_WIDTH-1];
        end
    end

    generate
        for (i=0;i<`RENAME_WIDTH;i=i+1) begin: gen_for
            if (i==0) begin : gen_if
                assign sepc_disp_pc_acc[i] = i_enq_vld[i] ? (i_enq_inst[i].isRVC ? 2 : 4) : 0;
                assign spec_disp_pc_vec[i] = spec_disp_pc_base;
            end
            else begin : gen_else
                assign sepc_disp_pc_acc[i] = (i_enq_vld[i] ? (i_enq_inst[i].isRVC ? 2 : 4) : 0) + sepc_disp_pc_acc[i-1];
                assign spec_disp_pc_vec[i] = spec_disp_pc_base + sepc_disp_pc_acc[i-1];
            end
        end
    endgenerate


    //alloc rob id
    wire[`WDEF(`RENAME_WIDTH)] insert_rob_vec;
    robIdx_t robIdx_vec[`RENAME_WIDTH];
    //alloc immBubbfer id
    wire[`WDEF(`RENAME_WIDTH)] use_imm_vec;
    immBIdx_t immBIdx_vec[`RENAME_WIDTH];
    wire[`IMMDEF] imm_vec[`RENAME_WIDTH];
    //alloc branchBuffer id
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


    wire[`WDEF(`RENAME_WIDTH)] insert_rob_vld;
    wire[`WDEF(`RENAME_WIDTH)] insert_intDQ_vld;
    wire[`WDEF(`RENAME_WIDTH)] insert_memDQ_vld;
    always_comb begin
        for(a=0;a<`RENAME_WIDTH;a=a+1) begin
            insert_intDQ_vld[a] = false;
            insert_memDQ_vld[a] = false;
            insert_rob_vld[a] = false;
            if (i_enq_vld[a]) begin
                insert_rob_vld[a] = true;
                if (i_enq_inst[a].disqQue_id == `INTBLOCK_ID && (!i_enq_inst[a].ismv)) begin
                    insert_intDQ_vld[a] = true;
                end
                else if (i_enq_inst[a].disqQue_id == `MEMBLOCK_ID) begin
                    insert_memDQ_vld[a] = true;
                end
            end
        end
    end
    `ORDER_CHECK(insert_rob_vld);

/******************** rob ********************/


/******************** int block ********************/

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

/******************** mem block ********************/
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

/******************** branch buffer ********************/
    typedef struct packed {
        logic[`XDEF] pc;
        logic[`XDEF] npc;
    } pc_and_npc_t;

    dataQue
    #(
        .DEPTH        ( 30        ),
        .INPORT_NUM   ( `RENAME_WIDTH   ),
        .READPORT_NUM ( READPORT_NUM ),
        .CLEAR_WID    ( CLEAR_WID    ),
        .dtype        ( pc_and_npc_t        )
    )
    u_branchBuffer(
        .clk          ( clk          ),
        .rst          ( rst          ),

        .o_can_enq    ( o_can_enq    ),
        .i_enq_req    ( i_enq_req    ),
        .i_enq_data   (    ),
        .o_alloc_id   ( o_alloc_id   ),

        .i_read_dqIdx ( i_read_dqIdx ),
        .o_read_data  (   ),

        .i_wb_vld     ( i_wb_vld     ),
        .i_wb_dqIdx   ( i_wb_dqIdx   )
    );

/******************** imm buffer ********************/
    dataQue
    #(
        .DEPTH        ( 30       ),
        .INPORT_NUM   ( `RENAME_WIDTH   ),
        .READPORT_NUM ( READPORT_NUM ),
        .CLEAR_WID    ( CLEAR_WID    ),
        .dtype        ( logic[`IMMDEF]        )
    )
    u_immBuffer(
        .clk          ( clk          ),
        .rst          ( rst          ),

        .o_can_enq    ( o_can_enq    ),
        .i_enq_req    ( use_imm_vec    ),
        .i_enq_data   ( imm_vec   ),
        .o_alloc_id   ( immBIdx_vec   ),

        .i_read_dqIdx ( i_read_dqIdx ),
        .o_read_data  ( o_read_data  ),

        .i_wb_vld     ( i_wb_vld     ),
        .i_wb_dqIdx   ( i_wb_dqIdx   )
    );


endmodule








