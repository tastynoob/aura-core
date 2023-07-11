`include "core_define.svh"





module regfile #(
    parameter int READPORT_NUM = 10,
    parameter int WBPORT_NUM = 6,
    parameter int SIZE = 80,
    parameter int HAS_ZERO = 1
)(
    input wire clk,
    input wire rst,

    input wire[`WDEF($clog2(SIZE))] i_read_idx[READPORT_NUM],
    output wire[`XDEF] o_read_data[READPORT_NUM],

    input wire[`WDEF(WBPORT_NUM)] i_write_en,
    input wire[`WDEF($clog2(SIZE))] i_write_idx[WBPORT_NUM],
    input wire[`XDEF] i_write_data[WBPORT_NUM]
);
    integer i;
    generate
        if (HAS_ZERO != 0) begin:gen_has_zero
            reg[`XDEF] buffer[1:SIZE];

            always_ff @(posedge clk) begin
                for (i=0;i<WBPORT_NUM;i=i+1) begin
                    if (i_write_en[i]) begin
                        buffer[i_write_idx[i]] <= i_write_data[i];
                    end
                end
            end

            always_comb begin : blockName
                for (i=0;i<READPORT_NUM;i=i+1) begin
                    if (i_read_idx[i] == 0) begin
                        o_read_data[i] = 0;
                    end
                    else begin
                        o_read_data[i] = buffer[i_read_idx[i]];
                    end
                end
            end
        end
        else begin : gen_no_zero
            reg[`XDEF] buffer[SIZE];

            always_ff @(posedge clk) begin
                for (i=0;i<WBPORT_NUM;i=i+1) begin
                    if (i_write_en[i]) begin
                        buffer[i_write_idx[i]] <= i_write_data[i];
                    end
                end
            end

            always_comb begin : blockName
                for (i=0;i<READPORT_NUM;i=i+1) begin
                    o_read_data[i] = buffer[i_read_idx[i]];
                end
            end
        end
    endgenerate



endmodule
