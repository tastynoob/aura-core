`include "core_define.svh"



// unorder in
// order out
module dispQue #(
    parameter int DEPTH = 4,
    parameter int INPORT_NUM  = 3,
    parameter int OUTPORT_NUM = 4,
    parameter type dtype = logic
) (
    input wire clk,
    input wire rst,
    input wire i_flush,

    // enq
    output wire o_can_enq,
    input wire i_enq_vld, // only when enq_vld is true, can enq
    input wire [`WDEF(INPORT_NUM)] i_enq_req,
    input dtype i_enq_data[INPORT_NUM],
    // deq
    output wire [`WDEF(OUTPORT_NUM)] o_can_deq,
    input wire [`WDEF(OUTPORT_NUM)] i_deq_req,
    output dtype o_deq_data[OUTPORT_NUM]

);

    wire[`WDEF(INPORT_NUM)] reorder_enq_req;
    dtype reorder_enq_data[INPORT_NUM];

    reorder
    #(
        .dtype ( dtype ),
        .NUM   ( INPORT_NUM   )
    )
    u_reorder_0(
        .i_data_vld      ( i_enq_req        ),
        .i_datas         ( i_enq_data       ),

        .o_data_vld      ( reorder_enq_req  ),
        .o_reorder_datas ( reorder_enq_data )
    );


    fifo
    #(
        .dtype       ( dtype       ),
        .INPORT_NUM  ( INPORT_NUM  ),
        .OUTPORT_NUM ( OUTPORT_NUM ),
        .DEPTH       ( DEPTH       ),
        .USE_INIT    ( 0    )
    )
    u_fifo(
        .init_data  (  ),
        .clk        ( clk        ),
        .rst        ( rst        ),
        .i_flush    ( i_flush    ),

        .o_can_enq  ( o_can_enq  ),
        .i_enq_vld  ( i_enq_vld  ),
        .i_enq_req  ( reorder_enq_req  ),
        .i_enq_data ( reorder_enq_data ),

        .o_can_deq  ( o_can_deq  ),
        .i_deq_req  ( i_deq_req  ),
        .o_deq_data ( o_deq_data )
    );



endmodule








