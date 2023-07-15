
`include "core_define.svh"

module tb #(
    parameter int WIDTH = 4
)(
    input wire clk,
    input wire rst
);

fetchEntry_t temp = '{
inst : 32'b00000000000100001000000010110011,
ftq_idx:0,
ftqOffset:0,
has_except:0,
except:0
};


ctrlBlock u_ctrlBlock(
    .clk                   (clk                   ),
    .rst                   (rst                   ),

    .i_inst_vld            (4'b0001),
    .i_inst                ({temp,temp,temp,temp}),
    .i_wb_vld  (0),
    .i_branchwb_vld (0),
    .i_exceptwb_vld (0)
);




endmodule



