
`include "core_define.svh"

module tb (
    input clk,
    input rst
);

`ifdef DEBUG


dataQue
#(
    .DEPTH          (30          ),
    .INPORT_NUM     (4     ),
    .READPORT_NUM   (4   ),
    .CLEAR_WID      (4      ),
    .dtype          (  pc_and_npc_t       ),
    .ISBRANCHBUFFER ( 1 )
)
u_dataQue(
    .clk              (              ),
    .rst              (              ),
    .o_can_enq        (        ),
    .i_enq_req        (        ),
    .i_enq_data       (       ),
    .o_alloc_id       (       ),
    .i_read_dqIdx     (     ),
    .o_read_data      (      ),
    .i_wb_vld         (         ),
    .i_wb_dqIdx       (       ),
    .o_willClear_vld  (  ),
    .o_willClear_data ( )
);


`endif

endmodule


