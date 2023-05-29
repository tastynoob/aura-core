`include "core_define.svh"


//unordered in,out
module freelist(
    input wire clk,
    input wire rst,
    //alloc physic reg
    //free regs must lager than RENAME_WIDTH
    output wire o_can_alloc,
    input wire[`WDEF(`RENAME_WIDTH)] i_alloc_req,
    output iprIdx_t o_alloc_prIdx[`RENAME_WIDTH],
    //dealloc physic reg (it must have enough spec to dealloc)
    input wire[`WDEF(`COMMIT_WIDTH)] i_dealloc_req,
    input iprIdx_t i_dealloc_prIdx[`COMMIT_WIDTH],

    // from commit
    input wire i_resteer_vld,
    input wire[`WDEF(COMMIT_WID)] i_commit_vld
);

    wire[`WDEF(`COMMIT_WIDTH)] reorder_dealloc_req;

    iprIdx_t reorder_dealloc_prIdx[`COMMIT_WIDTH];

    reorder
    #(
        .dtype ( iprIdx_t       ),
        .NUM   ( `COMMIT_WIDTH  )
    )
    u_reorder(
        .i_data_vld      ( i_dealloc_req         ),
        .i_datas         ( i_dealloc_prIdx       ),
        .o_data_vld      ( reorder_dealloc_req   ),
        .o_reorder_datas ( reorder_dealloc_prIdx )
    );


    wire[`WDEF(`RENAME_WIDTH)] real_alloc_req;
    iprIdx_t deq_data[`RENAME_WIDTH];

    wire[`SDEF(`RENAME_WIDTH)] alloc_num;
    count_one
    #(
        .WIDTH ( `RENAME_WIDTH )
    )
    u_count_one(
        .i_a   ( i_alloc_req   ),
        .o_sum ( alloc_num )
    );

    //reorder the alloc_vld bits: 1001 - > 0011
    assign real_alloc_req = ((|i_alloc_req) & (o_can_alloc))  ? (`RENAME_WIDTH'd1<<alloc_num) - 1 : 0;

    // the reg x0 is no need to save to freelist
    iprIdx_t free_list_init_data[`IPHYREG_NUM - 1];
    generate
        genvar i;
        for(i=0;i<`IPHYREG_NUM - 1;i=i+1) begin : gen_init
            assign free_list_init_data[i] = i + 1;
        end
    endgenerate

    wire[`WDEF(`RENAME_WIDTH)] can_deq;
    wire can_enq;
    `ASSERT(can_enq==true);
    fifo
    #(
        .dtype       ( iprIdx_t       ),
        .INPORT_NUM  (`COMMIT_WIDTH  ),
        .OUTPORT_NUM (`RENAME_WIDTH ),
        .DEPTH       (`IPHYREG_NUM - 1       ),
        .USE_INIT    ( 1 ),
        // only for rename
        .USE_RENAME  ( 1 ),
        .COMMIT_WID  ( `COMMIT_WIDTH )
    )
    u_fifo(
        .init_data   ( free_list_init_data ),
        .clk         ( clk         ),
        .rst         ( rst         ),
        .i_flush     ( 0           ),

        .o_can_enq   ( can_enq ),//dont care, it must have enough free entry to write
        .i_enq_vld   ( |reorder_dealloc_req   ),
        .i_enq_req   ( reorder_dealloc_req    ),
        .i_enq_data  ( reorder_dealloc_prIdx  ),

        .o_can_deq   ( can_deq          ),
        .i_deq_req   ( real_alloc_req   ),
        .o_deq_data  ( deq_data     ),

        .i_resteer_vld ( i_resteer_vld ),
        .i_commit_vld  ( i_commit_vld  )
    );


    //redirect fifo output to alloc_data
    //xxab -(redirect bits: 1001)> axxb
    redirect
    #(
        .dtype ( iprIdx_t ),
        .NUM   ( `RENAME_WIDTH   )
    )
    u_redirect(
        .i_arch_vld       ( i_alloc_req       ),
        .i_arch_datas     ( deq_data     ),
        .o_redirect_datas ( o_alloc_prIdx )
    );

    wire[`SDEF(`RENAME_WIDTH)] can_deq_num;

    count_one
    #(
        .WIDTH ( `RENAME_WIDTH )
    )
    u_count_one(
        .i_a   ( can_deq   ),
        .o_sum ( can_deq_num )
    );

    assign o_can_alloc = can_deq_num >= alloc_num;

endmodule
