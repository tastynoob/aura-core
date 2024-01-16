`include "frontend_define.svh"

import "DPI-C" function void ubtb_update_new_block(uint64_t startAddr, uint64_t fallthru, uint64_t target, uint64_t scnt);

`define TAG_WIDTH 8
`define TARGET_WIDTH 11 // actually is (11+1)

typedef struct packed {
    logic vld;
    logic[`WDEF(`TAG_WIDTH)] tag;
    logic[`WDEF($clog2(`FTB_PREDICT_WIDTH))] fallthruOffset;
    logic[`WDEF(`TARGET_WIDTH)] targetAddr;
    logic[`WDEF(2)] scnt;
} uBTBEntry_t;



module uBTB #(
    parameter int DEPTH = 32
) (
    input wire clk,
    input wire rst,

    input wire[`XDEF] i_lookup_pc,
    input wire[`WDEF(`BRHISTORYLENGTH)] i_gbh,

    output uBTBInfo_t o_uBTBInfo,

    input wire i_update,
    input wire[`XDEF] i_update_pc,
    input wire[`WDEF(`BRHISTORYLENGTH)] i_arch_gbh,
    input uBTBInfo_t i_updateInfo
);

    uBTBEntry_t buffer[DEPTH];

    wire[`WDEF($clog2(DEPTH))] index;
    assign index = i_lookup_pc[$clog2(DEPTH):1]; // ^ i_gbh[$clog2(DEPTH)-1:0];

    wire[`WDEF(`TAG_WIDTH)] tag;
    assign tag = (i_lookup_pc[`TAG_WIDTH:1] ^ i_lookup_pc[2*`TAG_WIDTH:`TAG_WIDTH+1]);

    uBTBEntry_t indexed_data;
    assign indexed_data = buffer[index];

    wire hit = (indexed_data.tag == tag) && indexed_data.vld;
    wire taken = hit && (indexed_data.scnt >= 2);
    wire[`XDEF] fallthruAddr = (i_lookup_pc + indexed_data.fallthruOffset);
    wire[`XDEF] targetAddr = {i_lookup_pc[`XLEN-1: `TARGET_WIDTH + 1], indexed_data.targetAddr, 1'b0};
    wire[`XDEF] nextAddr = (taken ? targetAddr : fallthruAddr);

    assign o_uBTBInfo = '{
        hit : hit,
        taken : taken,
        scnt : indexed_data.scnt,
        fallthruAddr : fallthruAddr,
        targetAddr : targetAddr,
        nextAddr : nextAddr
    };

    wire[`WDEF($clog2(DEPTH))] uindex;
    assign uindex = i_update_pc[$clog2(DEPTH):1]; //^ i_arch_gbh[$clog2(DEPTH)-1:0];
    wire[`WDEF(`TAG_WIDTH)] utag;
    assign utag = (i_update_pc[`TAG_WIDTH:1] ^ i_update_pc[2*`TAG_WIDTH:`TAG_WIDTH+1]);
    wire[`WDEF($clog2(`FTB_PREDICT_WIDTH))] ufallthruOffset;
    assign ufallthruOffset = (i_updateInfo.fallthruAddr - i_update_pc);
    wire[`WDEF(`TARGET_WIDTH)] utargetAddr;
    assign utargetAddr = i_updateInfo.targetAddr[`TARGET_WIDTH:1];

    always_ff @( posedge clk ) begin
        int fa;
        if (rst) begin
            for (fa=0; fa<DEPTH; fa=fa+1) begin
                buffer[fa].vld <= 0;
                buffer[fa].scnt <= 3;
            end
        end
        else begin
            if (i_update) begin
                buffer[uindex] <= '{
                    vld : 1,
                    tag : utag,
                    fallthruOffset : ufallthruOffset,
                    targetAddr : utargetAddr,
                    scnt : i_updateInfo.scnt
                };
                ubtb_update_new_block(i_update_pc, i_updateInfo.fallthruAddr, i_updateInfo.targetAddr, i_updateInfo.scnt);
            end
        end
    end

endmodule


