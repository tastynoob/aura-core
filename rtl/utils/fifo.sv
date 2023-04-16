`include "base.svh"
`include "funcs.svh"
import funcs::*;

//unsafed fifo
//ordered in out
module fifo #(
    parameter type dtype = logic,
    parameter int INPORT_NUM = 4,
    parameter int OUTPORT_NUM = 4,
    parameter int DEPTH = 32,
    parameter int USE_INIT = 0
) (
    input dtype init_data[DEPTH],
    input wire clk,
    input wire rst,
    input wire i_flush,
    //
    output wire [`WDEF(INPORT_NUM)] o_can_write,
    input wire [`WDEF(INPORT_NUM)] i_data_wen,
    input dtype i_data_wr[INPORT_NUM],
    //
    output wire [`WDEF(OUTPORT_NUM)] o_can_read,
    input wire [`WDEF(OUTPORT_NUM)] i_data_ren,
    output dtype o_data_rd[OUTPORT_NUM]
);
    wire [`SDEF(DEPTH)] write_num, read_num;
    continuous_one #(
        .WIDTH(INPORT_NUM)
    ) u_continuous_one_0 (
        .i_a  (i_data_wen),
        .o_sum(write_num)
    );
    continuous_one #(
        .WIDTH(OUTPORT_NUM)
    ) u_continuous_one_1 (
        .i_a  (i_data_wen),
        .o_sum(read_num)
    );
    dtype buffer[DEPTH];
    reg [`SDEF(DEPTH)] wptr[INPORT_NUM], rptr[OUTPORT_NUM], count;

    generate
        genvar i;
        if (USE_INIT) begin : gen_init
            for(i=0;i<DEPTH;i=i+1) begin:gen_init_
                always_ff @(posedge clk) begin
                    if((rst==true) || (i_flush == true)) begin
                        buffer[i] <= init_data[i];
                    end
                end
            end
        end
    endgenerate

    always_ff @(posedge clk) begin
        if ((rst == true) || (i_flush == true)) begin
            count <= 0;
            for (int i = 0; i < INPORT_NUM; i = i + 1) begin
                wptr[i] <= i;
            end
            for (int i = 0; i < OUTPORT_NUM; i = i + 1) begin
                rptr[i] <= i;
            end
        end else begin
            //push
            for (int i = 0; i < INPORT_NUM; i = i + 1) begin
                if (i_data_wen[i] == true) begin
                    buffer[wptr[i]] <= i_data_wr[i];
                end
                if (i_data_wen[0] == true) begin
                    wptr[i] <= wptr[i] + write_num - (wptr[i] < (DEPTH-INPORT_NUM+i) ? 0 : DEPTH);
                end
            end
            //pop
            for (int i = 0; i < OUTPORT_NUM; i = i + 1) begin
                if (i_data_ren[i] == true) begin
                end
                if (i_data_ren[0] == true) begin
                    rptr[i] <= rptr[i] + read_num - (rptr[i] < (DEPTH-OUTPORT_NUM+i) ? 0 : DEPTH);
                end
            end
            count <= count + write_num - read_num;
        end
    end

    wire [`SDEF(DEPTH)] can_read_num, can_write_num;
    assign can_read_num  = count;
    assign can_write_num = DEPTH - count;


    generate
        for (i = 0; i < INPORT_NUM; i = i + 1) begin : gen_input
            assign o_can_write[i] = i < can_write_num;
        end
        for (i = 0; i < OUTPORT_NUM; i = i + 1) begin : gen_output
            assign o_can_read[i] = i < can_read_num;
            assign o_data_rd[i]  = buffer[rptr[i]];
        end
    endgenerate

    `ASSERT(count < DEPTH);
    `ORDER_CHECK(i_data_ren);
    `ORDER_CHECK(i_data_wen);
endmodule
