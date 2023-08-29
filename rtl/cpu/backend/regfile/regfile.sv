`include "core_define.svh"





module regfile #(
    parameter int READPORT_NUM = 10,
    parameter int WBPORT_NUM = 6,
    parameter int SIZE = 80,
    parameter int HAS_ZERO = 1
)(
    input wire clk,
    input wire rst,
    // rename to rob mark not ready
    input wire[`WDEF(`RENAME_WIDTH)] i_notready_mark,
    input iprIdx_t i_notready_iprIdx[`RENAME_WIDTH],
    // dispatch to issueQue read src is or not ready
    input iprIdx_t i_disp_check_iprsIdx[`RENAME_WIDTH * `NUMSRCS_INT],
    output wire[`WDEF(`NUMSRCS_INT)] o_disp_check_iprs_vld[`RENAME_WIDTH],

    input wire[`WDEF($clog2(SIZE))] i_read_idx[READPORT_NUM],
    output wire[`WDEF(READPORT_NUM)] o_data_rdy,
    output wire[`XDEF] o_read_data[READPORT_NUM],

    input wire[`WDEF(WBPORT_NUM)] i_write_en,
    input wire[`WDEF($clog2(SIZE))] i_write_idx[WBPORT_NUM],
    input wire[`XDEF] i_write_data[WBPORT_NUM]
);
    genvar i;
    generate
        if (HAS_ZERO != 0) begin:gen_has_zero
            reg[`XDEF] buffer[1:SIZE-1];
            reg[`WDEF(SIZE)] rdy_bit;
            logic[`WDEF(SIZE)] rdy_bit_bypass;

            always_ff @(posedge clk) begin
                int fa;
                if (rst) begin
                    rdy_bit <= 0;
                end
                else begin
                    rdy_bit <= rdy_bit_bypass;
                    for (fa=0;fa<WBPORT_NUM;fa=fa+1) begin
                        if (i_write_en[fa]) begin
                            buffer[i_write_idx[fa]] <= i_write_data[fa];
                            assert (rdy_bit[i_write_idx[fa]] == 0);
                        end
                    end
                end
            end

            always_comb begin
                int ca;
                rdy_bit_bypass = rdy_bit;
                for (ca=0;ca<`RENAME_WIDTH;ca=ca+1) begin
                    if (i_notready_mark[ca]) begin
                        rdy_bit_bypass[i_notready_iprIdx[ca]] = 0;
                    end
                end
                for(ca=0;ca<WBPORT_NUM;ca=ca+1) begin
                    if (i_write_en[ca]) begin
                        rdy_bit_bypass[i_write_idx[ca]] = 1;
                    end
                end
            end

            reg[`XDEF] read_data[READPORT_NUM];
            reg[`WDEF(READPORT_NUM)] data_rdy;
            always_ff @( posedge clk ) begin
                int fa;
                for (fa=0;fa<READPORT_NUM;fa=fa+1) begin
                    read_data[fa] <= (i_read_idx[fa] == 0) ? 0 : buffer[i_read_idx[fa]];
                    data_rdy[fa] <= (i_read_idx[fa] == 0) ? 1 : rdy_bit[i_read_idx[fa]];
                end
            end

            assign o_read_data = read_data;
            assign o_data_rdy = data_rdy;
            // disp to IQ
            for (i=0;i<`RENAME_WIDTH * `NUMSRCS_INT;i=i+1) begin:gen_for
                // this should use rdy_bit_bypass;
                assign o_disp_check_iprs_vld[i/2][i%2] = (i_disp_check_iprsIdx[i] == 0) ? 1 : rdy_bit_bypass[i_disp_check_iprsIdx[i]];
            end
        end
        else begin : gen_no_zero
            // reg[`XDEF] buffer[SIZE];

            // always_ff @(posedge clk) begin
            //     int fa;
            //     for (fa=0;fa<WBPORT_NUM;fa=fa+1) begin
            //         if (i_write_en[fa]) begin
            //             buffer[i_write_idx[fa]] <= i_write_data[fa];
            //         end
            //     end
            // end

            // always_comb begin : blockName
            //     for (i=0;i<READPORT_NUM;i=i+1) begin
            //         o_read_data[i] = buffer[i_read_idx[i]];
            //     end
            // end
        end
    endgenerate



endmodule
