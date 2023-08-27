`include "base.svh"






module sramSet #(
    parameter int SETS = 32,
    parameter int WAYS = 4,
    parameter type dtype = logic,
    parameter int NEEDRESET = 0
)(
    input wire clk,
    input wire rst,

    input wire[`WDEF($clog2(SETS))] i_addr,
    input wire i_read_en,
    input wire[`WDEF(WAYS)] i_write_en_vec,
    output dtype o_read_data[WAYS],
    input dtype i_write_data[WAYS]
);
    localparam int WIDTH = $bits(dtype);

    genvar i;

    wire[`WDEF(WIDTH)] read_bits[WAYS];
    wire[`WDEF(WIDTH)] write_bits[WAYS];

    generate
        for(i=0;i<WAYS;i=i+1) begin
            assign write_bits[i] = i_write_data[i];
            assign o_read_data[i] = read_bits[i];
        end
    endgenerate

    generate
        for (i=0;i<WAYS;i=i+1) begin
            sram_1rw
            #(
                .DEPTH ( SETS ),
                .WIDTH ( WIDTH ),
                .NEEDRESET (NEEDRESET)
            )
            u_sram_1rw(
                .clk          ( clk        ),
                .rst          ( rst        ),
                .i_read_en    ( i_read_en  ),
                .i_write_en   ( i_write_en_vec[i] ),
                .i_addr       ( i_addr     ),
                .o_read_data  ( read_bits[i]  ),
                .i_write_data ( write_bits[i] )
            );
        end
    endgenerate

endmodule






