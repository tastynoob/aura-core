`include "frontend_define.svh"

import "DPI-C" function void ubtb_update_new_block(
    uint64_t uindex,
    uint64_t startAddr,
    uint64_t fallthru,
    uint64_t target,
    uint64_t scnt,
    uint64_t phtindex
);

import "DPI-C" function void ubtb_loookup(
    uint64_t lookup_pc,
    uint64_t endAddr,
    uint64_t targetAddr,
    uint64_t hit,
    uint64_t taken,
    uint64_t index,
    uint64_t phtindex
);

`define TAG_WIDTH 9
`define TARGET_WIDTH 11 // actually is (11+1)

typedef struct packed {
    logic vld;
    logic [`WDEF(`TAG_WIDTH)] tag;
    logic [`WDEF($clog2(`FTB_PREDICT_WIDTH))] fallthruOffset;
    logic [`WDEF(`TARGET_WIDTH)] targetAddr;
    BranchType::_ branch_type;
} uFTBEntry_t;

module uBTB #(
    parameter int DEPTH = 32
) (
    input wire clk,
    input wire rst,

    input wire [`XDEF] i_lookup_pc,
    input wire [`WDEF(`BRHISTORYLENGTH)] i_gbh,

    output uBTBInfo_t o_uBTBInfo,

    input wire i_update,
    input wire [`XDEF] i_update_pc,
    input wire [`WDEF(`BRHISTORYLENGTH)] i_arch_gbh,
    input uBTBInfo_t i_updateInfo
);
    localparam int PHTDEPTH = DEPTH * 4;

    uFTBEntry_t uftb[DEPTH];
    reg [`WDEF(2)] pht[PHTDEPTH];

    // lookup
    wire [`WDEF($clog2(DEPTH))] index_btb;
    wire [`WDEF($clog2(PHTDEPTH))] index_pht;
    wire [`WDEF(`TAG_WIDTH)] tag;
    assign index_btb = i_lookup_pc[$clog2(DEPTH)+1:2];
    assign index_pht = i_lookup_pc[$clog2(PHTDEPTH)+1:2] ^ i_gbh[$clog2(PHTDEPTH)-1:0];
    assign tag = (i_lookup_pc[`TAG_WIDTH:1] ^ i_lookup_pc[2*`TAG_WIDTH:`TAG_WIDTH+1]);

    uFTBEntry_t indexed_data;
    wire [`WDEF(2)] indexed_scnt;
    assign indexed_data = uftb[index_btb];
    assign indexed_scnt = pht[index_pht];

    wire hit = (indexed_data.tag == tag) && indexed_data.vld;
    wire taken = hit && ((indexed_scnt >= 2) || (indexed_data.branch_type > BranchType::isCond));
    wire [`XDEF] fallthruAddr = (i_lookup_pc + indexed_data.fallthruOffset);
    wire [`XDEF] targetAddr = {i_lookup_pc[`XLEN-1:`TARGET_WIDTH+1], indexed_data.targetAddr, 1'b0};
    wire [`XDEF] nextAddr = (taken ? targetAddr : fallthruAddr);

    assign o_uBTBInfo = '{
            hit : hit,
            taken : taken,
            fallthruAddr : fallthruAddr,
            targetAddr : targetAddr,
            nextAddr : nextAddr,
            branch_type : indexed_data.branch_type
        };

    // update
    wire [`WDEF($clog2(DEPTH))] uindex_btb;
    wire [`WDEF($clog2(PHTDEPTH))] uindex_pht;
    wire [`WDEF(`TAG_WIDTH)] utag;
    wire [`WDEF($clog2(`FTB_PREDICT_WIDTH))] ufallthruOffset;
    wire [`WDEF(`TARGET_WIDTH)] utargetAddr;
    assign uindex_btb = i_update_pc[$clog2(DEPTH)+1:2];
    assign uindex_pht = i_update_pc[$clog2(PHTDEPTH)+1:2] ^ i_arch_gbh[$clog2(PHTDEPTH)-1:0];
    assign utag = (i_update_pc[`TAG_WIDTH:1] ^ i_update_pc[2*`TAG_WIDTH:`TAG_WIDTH+1]);

    assign ufallthruOffset = (i_updateInfo.fallthruAddr - i_update_pc);
    assign utargetAddr = i_updateInfo.targetAddr[`TARGET_WIDTH:1];

    always_ff @(posedge clk) begin
        int fa;
        if (rst) begin
            for (fa = 0; fa < DEPTH; fa = fa + 1) begin
                uftb[fa].vld = 0;
            end
            for (fa = 0; fa < PHTDEPTH; fa = fa + 1) begin
                pht[fa] = 1;
            end
        end
        else begin
            ubtb_loookup(i_lookup_pc, fallthruAddr, targetAddr, hit, taken, index_btb, index_pht);
            if (i_update) begin
                uftb[uindex_btb] <= '{
                    vld : 1,
                    tag : utag,
                    fallthruOffset : ufallthruOffset,
                    targetAddr : utargetAddr,
                    branch_type : i_updateInfo.branch_type
                };
                if (i_updateInfo.branch_type == BranchType::isCond) begin
                    pht[uindex_pht] <= ftbFuncs::counterUpdate(pht[uindex_pht], i_updateInfo.taken);
                end
                ubtb_update_new_block(uindex_btb, i_update_pc, i_updateInfo.fallthruAddr, i_updateInfo.targetAddr,
                                      ftbFuncs::counterUpdate(pht[uindex_pht], i_updateInfo.taken), uindex_pht);
            end
        end
    end

endmodule


