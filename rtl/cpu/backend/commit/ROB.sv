`include "core_define.svh"


module ROB(
    input wire clk,
    input wire rst,

    //insert inst
    input wire[`WDEF(`RENAME_WIDTH)] i_insert,
    input ROBEntry_t i_new_entry[`RENAME_WIDTH],

    //write back
    input wire[`WDEF(`WB_WIDTH)] i_wb_vld,
    input wbInfo_t i_wbInfo[`WB_WIDTH],

    //to ctrl
    output wire[`WDEF(`COMMIT_WIDTH)] o_rename_commit,
    output renameCommitInfo_t o_rename_commitInfo[`COMMIT_WIDTH],

    //to bpu
    output wire[`WDEF(`COMMIT_WIDTH/2)] o_branch_commit,
    output branchCommitInfo_t o_branch_commitInfo[`COMMIT_WIDTH/2]
);

endmodule
