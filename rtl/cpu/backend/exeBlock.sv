`include "core_define.svh"



module exeBlock(
    input wire clk,
    input wire rst,

    input wire i_squash_vld,
    input squashInfo_t i_squashInfo,

    // from dispatch, mark the ipreg as not ready
    input wire[`WDEF(`RENAME_WIDTH)] i_disp_mark_notready_vld,
    input iprIdx_t i_disp_mark_notready_iprIdx[`RENAME_WIDTH],

    output wire[`WDEF(`INTDQ_DISP_WID)] o_intDQ_deq_vld,
    input wire[`WDEF(`INTDQ_DISP_WID)] i_intDQ_deq_req,
    input intDQEntry_t i_intDQ_deq_info[`INTDQ_DISP_WID],

    output wire[`WDEF(`MEMDQ_DISP_WID)] o_memDQ_deq_vld,
    input wire[`WDEF(`MEMDQ_DISP_WID)] i_memDQ_deq_req,
    input intDQEntry_t i_memDQ_deq_info[`MEMDQ_DISP_WID],

    output irobIdx_t o_read_irob_idx[`ALU_NUM],
    input imm_t i_read_irob_data[`ALU_NUM],
    // read ftq_startAddress (to ftq)
    output ftqIdx_t o_read_ftqIdx[`BRU_NUM],
    input wire[`XDEF] i_read_ftqStartAddr[`BRU_NUM],
    input wire[`XDEF] i_read_ftqNextAddr[`BRU_NUM],
    // read ftqOffste (to rob)
    output wire[`WDEF($clog2(`ROB_SIZE))] o_read_robIdx[`BRU_NUM],
    input ftqOffset_t i_read_ftqOffset[`BRU_NUM],

    // csr access
    input csr_in_pack_t i_csr_pack,
    csrrw_if.m if_csrrw,
    syscall_if.m if_syscall,

    // writeback to rob
    // common writeback
    output wire[`WDEF(`WBPORT_NUM)] o_fu_finished,
    output comwbInfo_t o_comwbInfo[`WBPORT_NUM],
    // branch writeback (branch taken or mispred)
    output wire[`WDEF(`BRU_NUM)] o_branchwb_vld,
    output branchwbInfo_t o_branchwb_info[`BRU_NUM],
    // except writeback
    output wire o_exceptwb_vld,
    output exceptwbInfo_t o_exceptwb_info
);
    localparam int IPRFREADPORTS = 12;
    localparam int IPRFWRITEPORTS = 6;

    genvar i;


    iprIdx_t disp_check_iprsIdx[`RENAME_WIDTH * `NUMSRCS_INT];
    wire[`WDEF(`NUMSRCS_INT)] disp_check_iprs_rdy[`RENAME_WIDTH];

    generate
        for (i=0;i<`RENAME_WIDTH * `NUMSRCS_INT;i=i+1) begin : gen_for
            assign disp_check_iprsIdx[i] = i_intDQ_deq_info[i/2].iprs_idx[i%2];
        end
    endgenerate


    iprIdx_t regfile_read_iprIdx[IPRFREADPORTS];
    wire[`WDEF(IPRFREADPORTS)] regfile_read_rdy;
    wire[`XDEF] regfile_read_data[IPRFREADPORTS];

    wire[`WDEF(IPRFWRITEPORTS)]  regfile_write_vld;
    iprIdx_t regfile_write_iprIdx[IPRFWRITEPORTS];
    wire[`XDEF] regfile_write_data[IPRFWRITEPORTS];
    regfile
    #(
        .READPORT_NUM ( IPRFREADPORTS ),
        .WBPORT_NUM   ( IPRFWRITEPORTS   ),
        .SIZE         ( `IPHYREG_NUM         ),
        .HAS_ZERO     ( 1     )
    )
    u_intPhysicRegfile(
        .clk                   ( clk                  ),
        .rst                   ( rst                  ),
        // rename to disp
        .i_notready_mark       ( i_disp_mark_notready_vld    ),
        .i_notready_iprIdx     ( i_disp_mark_notready_iprIdx ),
        // disp to issueQue
        .i_disp_check_iprsIdx  ( disp_check_iprsIdx   ),
        .o_disp_check_iprs_vld ( disp_check_iprs_rdy  ),

        .i_read_idx   ( regfile_read_iprIdx  ),
        .o_data_rdy   ( regfile_read_rdy     ),
        .o_read_data  ( regfile_read_data    ),

        .i_write_en   ( regfile_write_vld    ),
        .i_write_idx  ( regfile_write_iprIdx ),
        .i_write_data ( regfile_write_data   )
    );

    localparam int INTBLOCK_FUS = 6;

    iprIdx_t intBlock_iprs_idx[INTBLOCK_FUS][`NUMSRCS_INT];
    wire[`WDEF(`NUMSRCS_INT)] toIntBlock_iprs_rdy[INTBLOCK_FUS];
    wire[`XDEF] toIntBlock_iprs_data[INTBLOCK_FUS][`NUMSRCS_INT];

    wire[`WDEF(INTBLOCK_FUS)] intBlock_fu_finished;
    comwbInfo_t intBlock_comwbInfo[INTBLOCK_FUS];
    wire[`WDEF(`BRU_NUM)] intBlock_branchwb_vld;
    branchwbInfo_t intBlock_branchwb[`BRU_NUM];
    wire intBlock_exceptwb_vld;
    exceptwbInfo_t intBlock_exceptwb;


    intBlock
    #(
        .INPUT_NUM          ( `INTDQ_DISP_WID       ),
        .EXTERNAL_WRITEBACK ( 0 ),
        .EXTERNAL_WAKEUP    ( 0 ),
        .FU_NUM             ( INTBLOCK_FUS )
    )
    u_intBlock(
        .clk                 ( clk     ),
        .rst                 ( rst     ),

        .i_squash_vld        ( i_squash_vld       ),
        .i_squashInfo        ( i_squashInfo        ),

        .o_disp_vld          ( o_intDQ_deq_vld      ),
        .i_disp_req          ( i_intDQ_deq_req      ),
        .i_disp_info         ( i_intDQ_deq_info     ),
        .i_enq_iprs_rdy      ( disp_check_iprs_rdy  ),

        .o_iprs_idx          ( intBlock_iprs_idx    ),
        .i_iprs_ready        ( toIntBlock_iprs_rdy  ),
        .i_iprs_data         ( toIntBlock_iprs_data ),

        .o_immB_idx          ( o_read_irob_idx  ),
        .i_imm_data          ( i_read_irob_data ),

        .i_csr_pack          ( i_csr_pack ),
        .if_csrrw            ( if_csrrw   ),
        .if_syscall          ( if_syscall ),

        .o_read_ftqIdx       ( o_read_ftqIdx       ),
        .i_read_ftqStartAddr ( i_read_ftqStartAddr ),
        .i_read_ftqNextAddr  ( i_read_ftqNextAddr  ),
        .o_read_robIdx       ( o_read_robIdx       ),
        .i_read_ftqOffset    ( i_read_ftqOffset    ),

        .i_wb_stall        ( 0     ),
        .o_fu_finished     ( intBlock_fu_finished ),
        .o_comwbInfo       ( intBlock_comwbInfo     ),

        .o_branchWB_vld    ( intBlock_branchwb_vld ),
        .o_branchwb_info   ( intBlock_branchwb     ),
        .o_exceptwb_vld    ( intBlock_exceptwb_vld ),
        .o_exceptwb_info   ( intBlock_exceptwb     ),

        .i_ext_wake_vec    ( 0     ),
        .i_ext_wake_rdIdx  (      ),

        .i_ext_wb_vec      ( 0     ),
        .i_ext_wb_rdIdx    (      ),
        .i_ext_wb_data     (      )
    );







    // TODO: regfile read/write arbitration
    generate
        for(i=0;i<IPRFREADPORTS;i=i+1) begin : gen_for
            assign regfile_read_iprIdx[i] = intBlock_iprs_idx[i/2][i%2];
        end

        for(i=0;i<INTBLOCK_FUS;i=i+1) begin : gen_for
            assign toIntBlock_iprs_rdy[i][0] = regfile_read_rdy[i*2];
            assign toIntBlock_iprs_rdy[i][1] = regfile_read_rdy[i*2 + 1];
            assign toIntBlock_iprs_data[i][0] = regfile_read_data[i*2];
            assign toIntBlock_iprs_data[i][1] = regfile_read_data[i*2 + 1];
        end

        for(i=0;i<IPRFWRITEPORTS;i=i+1) begin : gen_for
            assign regfile_write_vld[i] = intBlock_fu_finished[i] && intBlock_comwbInfo[i].rd_wen;
            assign regfile_write_iprIdx[i] = intBlock_comwbInfo[i].iprd_idx;
            assign regfile_write_data[i] = intBlock_comwbInfo[i].result;
        end
    endgenerate

    assign o_fu_finished = intBlock_fu_finished;
    assign o_comwbInfo = intBlock_comwbInfo;


    assign o_branchwb_vld = intBlock_branchwb_vld;
    assign o_branchwb_info = intBlock_branchwb;

    assign o_exceptwb_vld = intBlock_exceptwb_vld;
    assign o_exceptwb_info = intBlock_exceptwb;

endmodule
