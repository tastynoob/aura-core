`include "base.svh"



module sram_1r1w #(
    parameter int DEPTH = 1024,
    parameter int WIDTH = 64
)(
    input wire clk,
    input wire rst,

    input wire[`WDEF($clog2(DEPTH))] i_read_addr,
    output wire[`WDEF(WIDTH)] o_read_data,

    input wire i_write_en,
    input wire[`WDEF($clog2(DEPTH))] i_write_addr,
    input wire[`WDEF(WIDTH)] i_write_data
);


`ifdef SIMULATION
    reg[`WDEF(WIDTH)] buffer[DEPTH];
    reg[`WDEF(WIDTH)] out_buf;
    always_ff @( posedge clk ) begin
        if (i_write_en) begin
            buffer[i_write_addr] <= i_write_data;
        end
        out_buf <= buffer[i_read_addr];
    end
    assign o_read_data = out_buf;
`endif

endmodule

