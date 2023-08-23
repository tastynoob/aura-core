`include "core_define.svh"






`SET_TRACE_OFF
module simRegfile (
    input wire clk,
    input wire rst,

    input wire[`WDEF(`WBPORT_NUM)] i_wb_vld,
    input ilrIdx_t i_wb_idx[`WBPORT_NUM],
    input wire[`XDEF] i_wb_data[`WBPORT_NUM]
);

    reg[`XDEF] regfile[32];
    logic[`XDEF] regfile_temp[32];

    always_comb begin
        int ca;
        regfile_temp = regfile;
        for (ca= `WBPORT_NUM - 1; ca >=0; ca=ca-1) begin
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
    wire[`XDEF] x1_ra = regfile[1];
    wire[`XDEF] x2_sp = regfile[2];
    wire[`XDEF] x3_gp = regfile[3];
    wire[`XDEF] x4_tp = regfile[4];
    wire[`XDEF] x5_t0 = regfile[5];
    wire[`XDEF] x6_t1 = regfile[6];
    wire[`XDEF] x7_t2 = regfile[7];
    wire[`XDEF] x8_s0 = regfile[8];
    wire[`XDEF] x9_s1 = regfile[9];
    wire[`XDEF] x10_a0 = regfile[10];
    wire[`XDEF] x11_a1 = regfile[11];
    wire[`XDEF] x12_a2 = regfile[12];
    wire[`XDEF] x13_a3 = regfile[13];
    wire[`XDEF] x14_a4 = regfile[14];
    wire[`XDEF] x15_a5 = regfile[15];
    wire[`XDEF] x16_a6 = regfile[16];
    wire[`XDEF] x17_a7 = regfile[17];
    wire[`XDEF] x18_s2 = regfile[18];
    wire[`XDEF] x19_s3 = regfile[19];
    wire[`XDEF] x20_s4 = regfile[20];
    wire[`XDEF] x21_s5 = regfile[21];
    wire[`XDEF] x22_s6 = regfile[22];
    wire[`XDEF] x23_s7 = regfile[23];
    wire[`XDEF] x24_s8 = regfile[24];
    wire[`XDEF] x25_s9 = regfile[25];
    wire[`XDEF] x26_s10 = regfile[26];
    wire[`XDEF] x27_s11 = regfile[27];
    wire[`XDEF] x28_t3 = regfile[28];
    wire[`XDEF] x29_t4 = regfile[29];
    wire[`XDEF] x30_t5 = regfile[30];
    wire[`XDEF] x31_t6 = regfile[31];


endmodule


