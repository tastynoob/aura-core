
`include "core_define.svh"



// DESIGN:
// issue -> read regfile/immBuffer/branchBuffer/fsq -> bypass/calcuate pc -> execute
// pc = (fsq_base_pc << offsetLen) + offset


// 4 alu
// 1 bju
// 2 mdu


module intBlock #(
    parameter int INPUT_NUM = `DISP_TO_INT_BLOCK_PORTNUM,
    parameter int ALU_NUM = 3,
    parameter int MDU_NUM = 2,
    parameter int MISC_NUM = 1
)(
    input wire clk,
    input wire rst,

    input wire i_squash_vld,
    // from dispatch
    input wire[`WDEF(INPUT_NUM)] i_disp_vld,
    input intDQEntry_t i_disp_info[INPUT_NUM],
    // regfile read
    output iprIdx_t o_iprs_idx[(ALU_NUM + MDU_NUM + MISC_NUM) * 2][`NUMSRCS_INT],// read regfile
    input wire[`WDEF((ALU_NUM + MDU_NUM + MISC_NUM) * 2)] o_iprs_ready[`NUMSRCS_INT],// ready or not
    input wire[`XDEF] i_iprs_data[(ALU_NUM + MDU_NUM + MISC_NUM) * 2][`NUMSRCS_INT],
    // immBuffer read
    output irobIdx_t o_immB_idx[ALU_NUM + MISC_NUM],
    input wire[`IMMDEF] i_imm_data[ALU_NUM + MISC_NUM],

    // fsq read
    output fsqIdx_t o_fsq_idx[MISC_NUM],

    // writeback
    output wire[`WDEF(ALU_NUM + MDU_NUM + MISC_NUM)] o_wb_vld,
    output commWBInfo_t o_commWB_info[ALU_NUM + MDU_NUM + MISC_NUM],
    output wire[`WDEF(MISC_NUM)] o_branchWB_vld,
    output branchWBInfo_t o_branchWB_info[MISC_NUM]

);


endmodule


