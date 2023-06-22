
`include "core_define.svh"




module exeIntBlock #(
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
    // to regfile
    output iprIdx_t o_iprs_idx[(ALU_NUM + MDU_NUM + MISC_NUM) * 2][`NUMSRCS_INT],// read regfile
    input wire[`WDEF((ALU_NUM + MDU_NUM + MISC_NUM) * 2)] o_iprs_ready[`NUMSRCS_INT],// ready or not
    input wire[`XDEF] i_iprs_data[(ALU_NUM + MDU_NUM + MISC_NUM) * 2][`NUMSRCS_INT],

    output wire[`WDEF(ALU_NUM + MDU_NUM + MISC_NUM)] o_iprd_vld, // write regfile
    output iprIdx_t o_iprd_idx[ALU_NUM + MDU_NUM + MISC_NUM],
    output wire[`XDEF] o_iprd_data[ALU_NUM + MDU_NUM + MISC_NUM],

    // to immBuffer
    output immBIdx_t o_immB_idx[ALU_NUM + MISC_NUM],
    input wire[`IMMDEF] i_imm_data[ALU_NUM + MISC_NUM]
);


endmodule


