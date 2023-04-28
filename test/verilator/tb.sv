
module tb (
    input clk,
    input rst
);

`ifdef DEBUG

    dataQue
    #(
        .DEPTH       ( 16       ),
        .INPORT_NUM  ( 4  ),
        .READPORT_NUM (4 ),
        .CLEAR_WID   ( 4   ),
        .dtype       ( logic[2:0]       ),
        .QUE_TYPE    ( 0    )
    )
    u_dataQue(
        .clk          ( clk         ),
        .rst          ( rst         ),
        .o_can_enq    (    ),
        .i_enq_req    (    ),
        .i_enq_data   (   ),
        .o_alloc_id   (   ),
        .i_read_dqIdx ( ),
        .o_read_data  (  ),
        .i_wb_vld     (     ),
        .i_wb_dqIdx   (   )
    );



`endif

endmodule


