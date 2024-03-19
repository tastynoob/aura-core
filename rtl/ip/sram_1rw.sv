`include "base.svh"



module sram_1rw #(
    parameter int DEPTH     = 1024,
    parameter int WIDTH     = 64,
    parameter int NEEDRESET = 0
) (
    input wire clk,
    input wire rst,
    input wire i_read_en,
    input wire i_write_en,
    input wire [`WDEF($clog2(DEPTH))] i_addr,
    output wire [`WDEF(WIDTH)] o_read_data,
    input wire [`WDEF(WIDTH)] i_write_data
);


`ifdef SIMULATION
    reg [`WDEF(WIDTH)] buffer[DEPTH];
    reg [`WDEF(WIDTH)] out_buf;
    always_ff @(posedge clk) begin
        int fa;
        if (rst) begin
            for (fa = 0; fa < DEPTH; fa = fa + 1) begin
                buffer[fa] = 0;
            end
        end
        else begin
            if (i_read_en) begin
                out_buf <= buffer[i_addr];
            end
            if (i_write_en) begin
                buffer[i_addr] <= i_write_data;
            end
        end
    end
    assign o_read_data = out_buf;
`endif

endmodule

