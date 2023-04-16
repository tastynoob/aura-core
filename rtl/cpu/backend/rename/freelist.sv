`include "rename_define.svh"


//unordered in,out
module freelist(
    input wire clk,
    input wire rst,
    //alloc physic reg
    //free regs must lager than RENAME_WIDTH
    output wire o_can_alloc,
    input wire[`WDEF(`RENAME_WIDTH)] i_alloc_req,
    output iprIdx_t o_alloc_prIdx[`RENAME_WIDTH],
    //dealloc physic reg
    input wire[`WDEF(`COMMIT_WIDTH)] i_dealloc_req,
    input iprIdx_t i_dealloc_prIdx[`COMMIT_WIDTH]
);


    wire[`WDEF(`COMMIT_WIDTH)] real_dealloc_req;
    iprIdx_t real_dealloc_prIdx[`COMMIT_WIDTH];
    reorder
    #(
        .dtype ( iprIdx_t ),
        .NUM   ( `COMMIT_WIDTH   )
    )
    u_reorder(
        .i_data_vld      ( i_dealloc_req     ),
        .i_datas         ( i_dealloc_prIdx        ),
        .o_data_vld      ( real_dealloc_req     ),
        .o_reorder_datas ( real_dealloc_prIdx )
    );

    wire[`WDEF(`RENAME_WIDTH)] fifo_can_read;
    wire[`WDEF(`RENAME_WIDTH)] fifo_ren;
    iprIdx_t fifo_data_rd[`RENAME_WIDTH];

    wire[`SDEF(`RENAME_WIDTH)] fifo_ren_count;
    count_one
    #(
        .WIDTH ( `RENAME_WIDTH )
    )
    u_count_one(
        .i_a   ( i_alloc_req   ),
        .o_sum ( fifo_ren_count )
    );
    //reorder the alloc_vld bits: 1001 - > 0011
    assign fifo_ren = (fifo_ren_count == 0) || (!o_can_alloc)  ? 0 : (1<<fifo_ren_count) - 1;


    // the reg x0 is no need to save to freelist
    iprIdx_t free_list_init_data[`IPHYREG_NUM - 1];
    generate
        genvar i;
        for(i=0;i<`IPHYREG_NUM - 1;i=i+1) begin : gen_init
            assign free_list_init_data[i] = i + 1;
        end
    endgenerate
    fifo
    #(
        .dtype       ( iprIdx_t       ),
        .INPORT_NUM  (`COMMIT_WIDTH  ),
        .OUTPORT_NUM (`RENAME_WIDTH ),
        .DEPTH       (`IPHYREG_NUM - 1       ),
        .USE_INIT    ( true )
    )
    u_fifo(
        .init_data   ( free_list_init_data ),
        .clk         ( clk         ),
        .rst         ( rst         ),
        .i_flush     ( false     ),

        .o_can_write ( ),//dont care, it must have enough free entry to write
        .i_data_wen  ( real_dealloc_req ),
        .i_data_wr   ( real_dealloc_prIdx  ),

        .o_can_read  ( fifo_can_read  ),
        .i_data_ren  ( fifo_ren ),
        .o_data_rd   ( fifo_data_rd  )
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
        .i_arch_datas     ( fifo_data_rd     ),
        .o_redirect_datas ( o_alloc_prIdx )
    );
    assign o_can_alloc = &fifo_can_read;

endmodule
