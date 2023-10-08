







// dispatch -> IQ
//          -> LSQ


module memBlock #(
    parameter int INPUT_NUM = `ISSUE_WIDTH,
    parameter int EXTERNAL_WRITEBACK = 2,// 2 ldu
    parameter int EXTERNAL_WAKEUP = 2,// external wake up sources
    parameter int FU_NUM = 6
) (
    input wire clk,
    input wire rst,

    input wire i_squash_vld,
    input squashInfo_t i_squashInfo,

    // from dispatch
    output wire[`WDEF(INPUT_NUM)] o_disp_vld,
    input wire[`WDEF(INPUT_NUM)] i_disp_req,
    input memDQEntry_t i_disp_info[INPUT_NUM],
    input wire[`WDEF(`NUMSRCS_INT)] i_enq_iprs_rdy[INPUT_NUM],

    // regfile read
    output iprIdx_t o_iprs_idx[FU_NUM][`NUMSRCS_INT],// read regfile
    input wire[`WDEF(`NUMSRCS_INT)] i_iprs_ready[FU_NUM],// ready or not
    input wire[`XDEF] i_iprs_data[FU_NUM][`NUMSRCS_INT],
    // immBuffer read
    output irobIdx_t o_immB_idx[`ALU_NUM],
    input imm_t i_imm_data[`ALU_NUM],

    // read ftq_startAddress (to ftq)
    output ftqIdx_t o_read_ftqIdx[`BRU_NUM],
    input wire[`XDEF] i_read_ftqStartAddr[`BRU_NUM],
    input wire[`XDEF] i_read_ftqNextAddr[`BRU_NUM],
    // read ftqOffste (to rob)
    output wire[`WDEF($clog2(`ROB_SIZE))] o_read_robIdx[`BRU_NUM],
    input ftqOffset_t i_read_ftqOffset[`BRU_NUM],

    // writeback
    input wire[`WDEF(FU_NUM)] i_wb_stall,
    output wire[`WDEF(FU_NUM)] o_fu_finished,
    output comwbInfo_t o_comwbInfo[FU_NUM],
    output wire[`WDEF(`BRU_NUM)] o_branchWB_vld,
    output branchwbInfo_t o_branchwb_info[`BRU_NUM],
    output wire o_exceptwb_vld,
    output exceptwbInfo_t o_exceptwb_info,

    // external wake up (may be speculative)
    input wire[`WDEF(EXTERNAL_WAKEUP)] i_ext_wake_vec,
    input iprIdx_t i_ext_wake_rdIdx[EXTERNAL_WAKEUP],

    // external writeback
    input wire[`WDEF(EXTERNAL_WRITEBACK)] i_ext_wb_vec,
    input iprIdx_t i_ext_wb_rdIdx[EXTERNAL_WRITEBACK],
    input wire[`XDEF] i_ext_wb_data[EXTERNAL_WRITEBACK]
);











endmodule
