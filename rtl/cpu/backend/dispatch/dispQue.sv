`include "dispatch_define.svh"




module dispQue #(
    parameter int DEPTH = 4,
    parameter int INPORT_NUM  = `RENAME_WIDTH,
    parameter int OUTPORT_NUM = 4,
    parameter int DQTYPE = 0
) (
    input wire clk,
    input wire rst,
    input wire i_flush,

    output wire[`WDEF(INPORT_NUM)] o_can_write,
    input wire[`WDEF(INPORT_NUM)] i_data_wen,
    input dispQueEntry_t i_data_wr[INPORT_NUM],

    output wire[`WDEF(OUTPORT_NUM)] o_can_read,
    output wire[`WDEF(OUTPORT_NUM)] i_data_ren,
    output dispQueEntry_t o_data_rd[OUTPORT_NUM]

);

    fifo
    #(
        .dtype       ( dispQueEntry_t    ),
        .INPORT_NUM  (INPORT_NUM  ),
        .OUTPORT_NUM (OUTPORT_NUM ),
        .DEPTH       (DEPTH       ),
        .USE_INIT    (0    )
    )
    u_fifo(
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


endmodule








