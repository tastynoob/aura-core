`include "base.svh"

// DESIGN: read
// stage input signal
// read tag ram and data ram
// select data and output
// DESIGN: write
// write data search by lineIdx and wayIdx
module dataSet #(
    parameter int READPORT_NUM = 2,
    parameter int WRITEPORT_NUM = 2,
    parameter int ADDR_WIDTH = 64,
    parameter int LINES = 32,
    parameter int WAYS = 4,
    parameter type dtype = logic
)(
    input wire clk,
    input wire rst,

    // read data
    input wire[`WDEF(READPORT_NUM)] i_read_vld,
    input wire[`WDEF(ADDR_WIDTH)] i_read_addr[READPORT_NUM],
    // hit or not, output at the second cycle
    output wire [`WDEF(READPORT_NUM)] o_read_hit,

    output wire[`WDEF(READPORT_NUM)] o_read_finished,
    output dtype o_read_data[READPORT_NUM],

    // write data
    input wire[`WDEF(READPORT_NUM)] i_write_vld,
    input wire[`WDEF(ADDR_WIDTH)] i_write_addr[WRITEPORT_NUM],
    input dtype i_write_data[WRITEPORT_NUM],
    output wire [`WDEF(WRITEPORT_NUM)] o_write_hit
);








endmodule
