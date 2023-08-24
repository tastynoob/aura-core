`include "core_define.svh"






`SET_TRACE_OFF
module simRegfile (
    input wire clk,
    input wire rst,

    input wire[`WDEF(`COMMIT_WIDTH)] i_wb_vld,
    input ilrIdx_t i_wb_idx[`COMMIT_WIDTH],
    input wire[`XDEF] i_wb_data[`COMMIT_WIDTH]
);

    reg[`XDEF] regfile[32];
    logic[`XDEF] regfile_temp[32];

    always_comb begin
        int ca;
        regfile_temp = regfile;
        for (ca= `COMMIT_WIDTH - 1; ca >=0; ca=ca-1) begin
            if (i_wb_vld[ca]) begin
                regfile_temp[i_wb_idx[ca]] = i_wb_data[ca];
            end
        end
    end

    always_ff @( posedge clk ) begin
        int fa;
        if (rst) begin
            for(fa=0;fa<32;fa=fa+1) begin
                regfile[fa] = 0;
            end
        end
        else begin
            regfile <= regfile_temp;
        end
    end
`SET_TRACE_ON
    wire[`XDEF] x0_zero = 0;
    wire[`XDEF] x1_ra = regfile_temp[1];
    wire[`XDEF] x2_sp = regfile_temp[2];
    wire[`XDEF] x3_gp = regfile_temp[3];
    wire[`XDEF] x4_tp = regfile_temp[4];
    wire[`XDEF] x5_t0 = regfile_temp[5];
    wire[`XDEF] x6_t1 = regfile_temp[6];
    wire[`XDEF] x7_t2 = regfile_temp[7];
    wire[`XDEF] x8_s0 = regfile_temp[8];
    wire[`XDEF] x9_s1 = regfile_temp[9];
    wire[`XDEF] x10_a0 = regfile_temp[10];
    wire[`XDEF] x11_a1 = regfile_temp[11];
    wire[`XDEF] x12_a2 = regfile_temp[12];
    wire[`XDEF] x13_a3 = regfile_temp[13];
    wire[`XDEF] x14_a4 = regfile_temp[14];
    wire[`XDEF] x15_a5 = regfile_temp[15];
    wire[`XDEF] x16_a6 = regfile_temp[16];
    wire[`XDEF] x17_a7 = regfile_temp[17];
    wire[`XDEF] x18_s2 = regfile_temp[18];
    wire[`XDEF] x19_s3 = regfile_temp[19];
    wire[`XDEF] x20_s4 = regfile_temp[20];
    wire[`XDEF] x21_s5 = regfile_temp[21];
    wire[`XDEF] x22_s6 = regfile_temp[22];
    wire[`XDEF] x23_s7 = regfile_temp[23];
    wire[`XDEF] x24_s8 = regfile_temp[24];
    wire[`XDEF] x25_s9 = regfile_temp[25];
    wire[`XDEF] x26_s10 = regfile_temp[26];
    wire[`XDEF] x27_s11 = regfile_temp[27];
    wire[`XDEF] x28_t3 = regfile_temp[28];
    wire[`XDEF] x29_t4 = regfile_temp[29];
    wire[`XDEF] x30_t5 = regfile_temp[30];
    wire[`XDEF] x31_t6 = regfile_temp[31];


endmodule


