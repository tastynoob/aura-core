`include "core_define.svh"



module exeBlock(
    input wire clk,
    input wire rst,

    input wire i_squash_vld,
    input squashInfo_t i_squashInfo,

    // from dispatch, mark the ipreg as not ready
    input wire[`WDEF(`RENAME_WIDTH)] i_disp_mark_notready_vld,
    input iprIdx_t i_disp_mark_notready_iprIdx[`RENAME_WIDTH],

    disp_if.s if_disp,

    output irobIdx_t o_read_irob_idx[`IMMBUFFER_READPORT_NUM],
    input imm_t i_read_irob_data[`IMMBUFFER_READPORT_NUM],
    output wire[`WDEF(`IMMBUFFER_CLEARPORT_NUM)] o_immB_clear_vld,
    output irobIdx_t o_immB_clear_idx[`IMMBUFFER_CLEARPORT_NUM],

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
    output wire[`WDEF(`COMPLETE_NUM)] o_fu_finished,
    output comwbInfo_t o_comwbInfo[`COMPLETE_NUM],
    // branch writeback (branch taken or mispred)
    output wire[`WDEF(`BRU_NUM)] o_branchwb_vld,
    output branchwbInfo_t o_branchwb_info[`BRU_NUM],
    // except writeback
    output wire o_exceptwb_vld,
    output exceptwbInfo_t o_exceptwb_info
);
    // 4 alu + 2 mdu + 2 ldu + 2 st
    // 4*2 + 2*2 + 2 + 2*2
    localparam int INTBLOCK_IPRFREADPORTS = `ALU_NUM*2 + `MDU_NUM*2;// 12
    localparam int MEMBLOCK_IPRFREADPORTS = `LDU_NUM + `STU_NUM*2;// 6
    localparam int IPRFREADPORTS = `ALU_NUM*2 + `MDU_NUM*2 + `LDU_NUM + `STU_NUM*2;// 18
    localparam int TOTALDISPWIDTH = (`INTDQ_DISP_WID + `MEMDQ_DISP_WID);

    genvar i, j;

    iprIdx_t disp_check_iprsIdx[TOTALDISPWIDTH * `NUMSRCS_INT];
    wire[`WDEF(TOTALDISPWIDTH * `NUMSRCS_INT)] disp_check_iprs_rdy;

    wire[`WDEF(`NUMSRCS_INT)] disp_int_iprs_rdy[`INTDQ_DISP_WID];
    wire[`WDEF(`NUMSRCS_INT)] disp_mem_iprs_rdy[`MEMDQ_DISP_WID];
    wire disp_mem_dep_rdy[`MEMDQ_DISP_WID];

    generate
        for (i=0;i<TOTALDISPWIDTH * `NUMSRCS_INT;i=i+1) begin
            if (i < `INTDQ_DISP_WID * `NUMSRCS_INT) begin
                assign disp_check_iprsIdx[i] =
                        if_disp.int_info[i/2].iprs[i%2];
            end
            else if (i < TOTALDISPWIDTH * `NUMSRCS_INT) begin
                assign disp_check_iprsIdx[i] =
                        if_disp.mem_info[(i - `INTDQ_DISP_WID)/2].iprs[(i - `INTDQ_DISP_WID)%2];
            end
        end
        for (i=0; i<`INTDQ_DISP_WID; i=i+1) begin
            for (j=0; j<`NUMSRCS_INT; j=j+1) begin
                assign disp_int_iprs_rdy[i][j] = disp_check_iprs_rdy[i * `NUMSRCS_INT + j];
            end
        end
        for (i=0; i<`MEMDQ_DISP_WID; i=i+1) begin
            for (j=0; j<`NUMSRCS_INT; j=j+1) begin
                assign disp_mem_iprs_rdy[i][j] = disp_check_iprs_rdy[i * `NUMSRCS_INT + j + (`INTDQ_DISP_WID * `NUMSRCS_INT)];
            end
        end
    endgenerate

    iprIdx_t regfile_read_iprIdx[IPRFREADPORTS];
    wire[`WDEF(IPRFREADPORTS)] regfile_read_rdy;
    wire[`XDEF] regfile_read_data[IPRFREADPORTS];

    wire[`WDEF(`WBPORT_NUM)]  intRF_write_vec;
    iprIdx_t intRF_write_iprd[`WBPORT_NUM];
    wire[`XDEF] intRF_write_data[`WBPORT_NUM];
    regfile
    #(
        .READPORT_NUM ( IPRFREADPORTS  ),
        .WBPORT_NUM   ( `WBPORT_NUM ),
        .DISPWIDTH    ( TOTALDISPWIDTH ),
        .SIZE         ( `IPHYREG_NUM  ),
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

        .i_write_en   ( intRF_write_vec    ),
        .i_write_idx  ( intRF_write_iprd ),
        .i_write_data ( intRF_write_data   )
    );

    loadwake_if if_loadwake();

    wire[`WDEF(`BYPASS_WIDTH)] glob_bp_vec;
    iprIdx_t glob_bp_iprd[`BYPASS_WIDTH];
    wire[`XDEF] glob_bp_data[`BYPASS_WIDTH];

    localparam int INTBLOCK_FUS = `ALU_NUM + `MDU_NUM;//6

    iprIdx_t intBlock_iprs_idx[INTBLOCK_FUS][`NUMSRCS_INT];
    wire[`WDEF(`NUMSRCS_INT)] toIntBlock_iprs_rdy[INTBLOCK_FUS];
    wire[`XDEF] toIntBlock_iprs_data[INTBLOCK_FUS][`NUMSRCS_INT];

    irobIdx_t intBlock_irob_idx[`ALU_NUM];
    imm_t toIntBlock_imm[`ALU_NUM];

    wire[`WDEF(INTBLOCK_FUS)] intBlk_fu_finished;
    comwbInfo_t intBlk_comwbInfo[INTBLOCK_FUS];
    wire[`WDEF(`BRU_NUM)] intBlock_branchwb_vld;
    branchwbInfo_t intBlock_branchwb[`BRU_NUM];
    wire intBlock_exceptwb_vld;
    exceptwbInfo_t intBlock_exceptwb;


    wire[`WDEF(`INT_SWAKE_WIDTH)] intBlk_swk_vec;
    iprIdx_t intBlk_swk_iprd[`INT_SWAKE_WIDTH];

    wire[`WDEF(`INT_WBPORT_NUM)] intBlk_bp_vec;
    iprIdx_t intBlk_bp_iprd[`INT_WBPORT_NUM];
    wire[`XDEF] intBlk_bp_data[`INT_WBPORT_NUM];

    intBlock u_intBlock(
        .clk                 ( clk     ),
        .rst                 ( rst     ),

        .i_squash_vld        ( i_squash_vld       ),
        .i_squashInfo        ( i_squashInfo        ),

        .if_disp             ( if_disp           ),
        .i_enq_iprs_rdy      ( disp_int_iprs_rdy ),

        .o_iprs_idx          ( intBlock_iprs_idx    ),
        .i_iprs_ready        ( toIntBlock_iprs_rdy  ),
        .i_iprs_data         ( toIntBlock_iprs_data ),

        .o_immB_idx          ( o_read_irob_idx[0:3]  ),
        .i_imm_data          ( i_read_irob_data[0:3] ),
        .o_immB_clear_vld    ( o_immB_clear_vld[3:0]),
        .o_immB_clear_idx    ( o_immB_clear_idx[0:3]),

        .i_csr_pack          ( i_csr_pack ),
        .if_csrrw            ( if_csrrw   ),
        .if_syscall          ( if_syscall ),

        .o_read_ftqIdx       ( o_read_ftqIdx       ),
        .i_read_ftqStartAddr ( i_read_ftqStartAddr ),
        .i_read_ftqNextAddr  ( i_read_ftqNextAddr  ),

        .o_read_robIdx       ( o_read_robIdx       ),
        .i_read_ftqOffset    ( i_read_ftqOffset    ),

        .i_wb_stall          ( 0     ),
        .o_fu_finished       ( intBlk_fu_finished ),
        .o_comwbInfo         ( intBlk_comwbInfo   ),

        .o_branchWB_vld      ( intBlock_branchwb_vld ),
        .o_branchwb_info     ( intBlock_branchwb     ),

        .o_exceptwb_vld      ( intBlock_exceptwb_vld ),
        .o_exceptwb_info     ( intBlock_exceptwb     ),

        .o_exp_swk_vec       ( intBlk_swk_vec        ),
        .o_exp_swk_iprd      ( intBlk_swk_iprd       ),

        .o_exp_bp_vec        ( intBlk_bp_vec        ),
        .o_exp_bp_iprd       ( intBlk_bp_iprd       ),
        .o_exp_bp_data       ( intBlk_bp_data       ),

        .i_glob_wbwk_vec     ( intRF_write_vec),
        .i_glob_wbwk_iprd    ( intRF_write_iprd ),

        .if_loadwake         ( if_loadwake          ),
        .i_glob_bp_vec       ( glob_bp_vec          ),
        .i_glob_bp_iprd      ( glob_bp_iprd         ),
        .i_glob_bp_data      ( glob_bp_data         )
    );

    localparam int MEMBLOCK_FUs = `LDU_NUM + `STU_NUM;//4

    // 2 : 2 load
    // 4 : 2 sta + 2 std
    iprIdx_t memBlk_iprd_idx[MEMBLOCK_IPRFREADPORTS];
    wire toMemBlk_iprs_rdy[MEMBLOCK_IPRFREADPORTS];
    wire[`XDEF] toMemBlk_iprs_data[MEMBLOCK_IPRFREADPORTS];

    assign disp_mem_dep_rdy = {0,0,0,0};

    irobIdx_t memBlock_irob_idx[`LDU_NUM + `STU_NUM];
    imm_t toMemBlock_imm[`LDU_NUM + `STU_NUM];

    wire[`WDEF(MEMBLOCK_FUs)] memBlk_fu_finished;
    comwbInfo_t memBlk_comwbInfo[MEMBLOCK_FUs];

    wire[`WDEF(`MEM_WBPORT_NUM)] memBlk_wk_vec;
    iprIdx_t memBlk_wk_iprd[`MEM_WBPORT_NUM];

    wire[`WDEF(`MEM_WBPORT_NUM)] memBlk_bp_vec;
    iprIdx_t memBlk_bp_iprd[`MEM_WBPORT_NUM];
    wire[`XDEF] memBlk_bp_data[`MEM_WBPORT_NUM];

    memBlock u_memBlock(
        .clk                 ( clk                 ),
        .rst                 ( rst                 ),

        .i_squash_vld        ( i_squash_vld        ),
        .i_squashInfo        ( i_squashInfo        ),

        .if_disp             ( if_disp             ),
        .i_enq_iprs_rdy      ( disp_mem_iprs_rdy     ),
        .i_enq_memdep_rdy    ( disp_mem_dep_rdy    ),

        .o_iprs_idx          ( memBlk_iprd_idx          ),
        .i_iprs_ready        ( toMemBlk_iprs_rdy        ),
        .i_iprs_data         ( toMemBlk_iprs_data         ),

        .o_immB_idx          ( memBlock_irob_idx          ),
        .i_imm_data          ( toMemBlock_imm          ),

        .o_read_ftqIdx       (),
        .i_read_ftqStartAddr (),
        .i_read_ftqNextAddr  (),

        .o_read_robIdx       (),
        .i_read_ftqOffset    (),

        .i_wb_stall          ( 0          ),
        .o_fu_finished       ( memBlk_fu_finished       ),
        .o_comwbInfo         ( memBlk_comwbInfo         ),

        .o_exceptwb_vld      (       ),
        .o_exceptwb_info     (      ),

        .if_loadwake         ( if_loadwake          ),

        .o_exp_bp_vec        ( memBlk_bp_vec        ),
        .o_exp_bp_iprd       ( memBlk_bp_iprd       ),
        .o_exp_bp_data       ( memBlk_bp_data       ),

        .i_glob_bp_vec       ( glob_bp_vec          ),
        .i_glob_bp_iprd      ( glob_bp_iprd         ),
        .i_glob_bp_data      ( glob_bp_data         )
    );

    assign o_immB_clear_vld[7:4] = 0;



    reg[`WDEF(`INT_WBPORT_NUM)] nxtIntWBVec;
    iprIdx_t nxtIntWBIprd[`INT_WBPORT_NUM];
    reg[`XDEF] nxtIntWBData[`INT_WBPORT_NUM];
    reg[`WDEF(`WBPORT_NUM)] nxtWBVec;
    iprIdx_t nxtWBIprd[`WBPORT_NUM];
    reg[`XDEF] nxtWBData[`WBPORT_NUM];
    always_ff @(posedge clk) begin
        if (rst) begin
            nxtIntWBVec <= 0;
            nxtWBVec <= 0;
        end
        else begin
            nxtIntWBVec <= intBlk_bp_vec;
            nxtIntWBIprd <= intBlk_bp_iprd;
            nxtIntWBData <= intBlk_bp_data;
            nxtWBVec <= intRF_write_vec;
            nxtWBIprd <= intRF_write_iprd;
            nxtWBData <= intRF_write_data;
        end
    end

    generate
        // global bypass
        for (i=0;i<`BYPASS_WIDTH;i=i+1) begin
            if (i < `INT_WBPORT_NUM) begin
                assign glob_bp_vec[i] = intBlk_bp_vec[i];
                assign glob_bp_iprd[i] = intBlk_bp_iprd[i];
                assign glob_bp_data[i] = intBlk_bp_data[i];
            end
            else if (i < `INT_WBPORT_NUM * 2) begin
                assign glob_bp_vec[i] = nxtIntWBVec[i - `INT_WBPORT_NUM];
                assign glob_bp_iprd[i] = nxtIntWBIprd[i - `INT_WBPORT_NUM];
                assign glob_bp_data[i] = nxtIntWBData[i - `INT_WBPORT_NUM];
            end
            else begin
                assign glob_bp_vec[i] = nxtWBVec[i - `INT_WBPORT_NUM * 2];
                assign glob_bp_iprd[i] = nxtWBIprd[i - `INT_WBPORT_NUM * 2];
                assign glob_bp_data[i] = nxtWBData[i - `INT_WBPORT_NUM * 2];
            end
        end
    endgenerate

    generate
        // regfile read
        for (i=0;i<IPRFREADPORTS;i=i+1) begin
            if (i < INTBLOCK_IPRFREADPORTS) begin
                assign regfile_read_iprIdx[i] = intBlock_iprs_idx[i/2][i%2];
            end
            else begin
                assign regfile_read_iprIdx[i] = memBlk_iprd_idx[i - INTBLOCK_IPRFREADPORTS];
            end
        end

        for(i=0;i<INTBLOCK_FUS;i=i+1) begin
            assign toIntBlock_iprs_rdy[i][0] = regfile_read_rdy[i*2];
            assign toIntBlock_iprs_rdy[i][1] = regfile_read_rdy[i*2 + 1];
            assign toIntBlock_iprs_data[i][0] = regfile_read_data[i*2];
            assign toIntBlock_iprs_data[i][1] = regfile_read_data[i*2 + 1];
        end

        for(i=0;i<MEMBLOCK_IPRFREADPORTS;i=i+1) begin
            assign toMemBlk_iprs_rdy[i] = regfile_read_rdy[i + INTBLOCK_IPRFREADPORTS];
            assign toMemBlk_iprs_data[i] = regfile_read_data[i + INTBLOCK_IPRFREADPORTS];
        end

        // regfile write
        for(i=0;i<`WBPORT_NUM;i=i+1) begin
            if (i < `ALU_NUM + `MDU_NUM) begin
                assign intRF_write_vec[i] = intBlk_fu_finished[i] && intBlk_comwbInfo[i].rd_wen;
                assign intRF_write_iprd[i] = intBlk_comwbInfo[i].iprd_idx;
                assign intRF_write_data[i] = intBlk_comwbInfo[i].result;
            end
            else begin
                assign intRF_write_vec[i] = 0;
                assign intRF_write_iprd[i] = 0;
                assign intRF_write_data[i] = 0;
            end
        end
    endgenerate

    // inst complete
    generate
        for (i=0; i<`COMPLETE_NUM; i=i+1) begin
            if (i < INTBLOCK_FUS) begin
                assign o_fu_finished[i] = intBlk_fu_finished[i];
                assign o_comwbInfo[i] = intBlk_comwbInfo[i];
            end
            else begin
                assign o_fu_finished[i] = memBlk_fu_finished[i - INTBLOCK_FUS];
                assign o_comwbInfo[i] = memBlk_comwbInfo[i - INTBLOCK_FUS];
            end
        end
    endgenerate

    // immBuffer read
    generate
        for (i=0; i<`IMMBUFFER_READPORT_NUM; i=i+1) begin
            if (i < `ALU_NUM) begin
                assign o_read_irob_idx[i] = intBlock_irob_idx[i];
                assign toIntBlock_imm[i] = i_read_irob_data[i];
            end
            else begin
                assign o_read_irob_idx[i] = memBlock_irob_idx[i - `ALU_NUM];
                assign toMemBlock_imm[i - `ALU_NUM] = i_read_irob_data[i];
            end
        end
    endgenerate

    assign o_branchwb_vld = intBlock_branchwb_vld;
    assign o_branchwb_info = intBlock_branchwb;

    assign o_exceptwb_vld = intBlock_exceptwb_vld;
    assign o_exceptwb_info = intBlock_exceptwb;

endmodule
