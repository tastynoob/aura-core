`include "core_define.svh"

//
module rename(
    input wire rst,
    input wire clk,
    // squash
    input wire i_squash_vld,
    input squashInfo_t i_squashInfo,
    // from commit
    input wire[`WDEF(`COMMIT_WIDTH)] i_commit_vld,
    input renameCommitInfo_t i_commitInfo[`COMMIT_WIDTH],
    // from decode
    input wire[`WDEF(`DECODE_WIDTH)] i_decinfo_vld,
    input decInfo_t i_decinfo[`DECODE_WIDTH],
    input wire[`XDEF] i_predTakenPC,
    // to dispatch
    output wire[`WDEF(`RENAME_WIDTH)] o_rename_vld,
    output renameInfo_t o_renameInfo[`RENAME_WIDTH]
);


endmodule

