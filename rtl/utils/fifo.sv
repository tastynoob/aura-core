`include "rtl/common/baseType.svh"
`include "rtl/common/funcs.svh"
import funcs::*;

module fifo #(
    parameter type dtype = logic,
    parameter int INPORT_NUM = 1,
    parameter int OUTPORT_NUM = 1,
    parameter int DEPTH = 32
) (
    input  wire  clk,
    input  wire  rst,
    input  wire  i_flush,
    //
    output wire  o_can_write[ INPORT_NUM],
    input  wire  i_data_wen [ INPORT_NUM],
    input  dtype i_data_wr  [ INPORT_NUM],
    //
    output wire  o_can_read [OUTPORT_NUM],
    input  wire  i_data_ren [OUTPORT_NUM],
    output dtype o_data_rd  [OUTPORT_NUM]
);
    wire [$clog2(DEPTH):0] write_num, read_num;
    assign write_num = $get_last_one_index({>>{i_data_wen}});
    assign read_num  = $get_last_one_index({>>{i_data_ren}});
    bool write_judge = &i_data_wen[0:write_num];
    bool read_judge = &i_data_ren[0:read_num];
    always_comb assert (write_num != 0 ? write_judge : true);
    always_comb assert (read_num != 0 ? read_judge : true);


    dtype buffer[DEPTH];
    reg [$clog2(DEPTH):0] wptr[INPORT_NUM], rptr[OUTPORT_NUM];
    always_ff @(posedge clk) begin
        if (rst == true) begin
            for (int i = 0; i < INPORT_NUM; i = i + 1) begin
                wptr <= i;
            end
            for (int i = 0; i < OUTPORT_NUM; i = i + 1) begin
                rptr <= i;
            end
        end else begin
            //push
            for (int i = 0; i < INPORT_NUM; i = i + 1) begin
                if (i_data_wen[i] == true) begin
                    buffer[wptr[i]] <= i_data_wr[i];
                end
            end
            //pop
            for (int i = 0; i < OUTPORT_NUM; i = i + 1) begin
                if (i_data_ren[i] == true) begin

                end
            end
        end
    end


    wire [$clog2(DEPTH):0] can_read_num;
    assign can_read_num = (wptr[0] > rptr[0] ? (wptr[0] - rptr[0]) : (DEPTH - (rptr[0] - wptr[0])));
    generate
        genvar i;
        for (i = 0; i < OUTPORT_NUM; i = i + 1) begin : gen_OUTPUT
            assign o_can_read[i] = i < can_read_num;
            assign o_data_rd[i]  = buffer[rptr[i]];
        end
    endgenerate

endmodule
