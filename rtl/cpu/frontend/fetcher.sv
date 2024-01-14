`include "frontend_define.svh"
`include "funcs.svh"


import "DPI-C" function void fetch_block(uint64_t startAddr, uint64_t endAddr, uint64_t nextAddr, uint64_t falsepred);
import "DPI-C" function uint64_t build_instmeta(uint64_t pc, uint64_t inst_code);
import "DPI-C" function void count_fetchToBackend(uint64_t n);

// FIXME:
// we need to check false predict (non-branch inst was predicted taken)
module fetcher (
    input wire clk,
    input wire rst,

    input wire i_squash_vld,
    input squashInfo_t i_squashInfo,

    // from backend
    input wire[`WDEF(`BRU_NUM)] i_branchwb_vld,
    input branchwbInfo_t i_branchwbInfo[`BRU_NUM],

    input ftqIdx_t i_read_ftqIdx[`BRU_NUM],
    output wire[`XDEF] o_read_ftqStartAddr[`BRU_NUM],
    output wire[`XDEF] o_read_ftqNextAddr[`BRU_NUM],

    // to backend
    input wire i_backend_stall,
    output wire[`WDEF(`FETCH_WIDTH)] o_fetch_inst_vld,
    output fetchEntry_t o_fetch_inst[`FETCH_WIDTH],

    input wire i_commit_vld,
    input ftqIdx_t i_commit_ftqIdx,

    // to icache
    core2icache_if.m if_core_fetch

);

    genvar i;

    // false predict, need to squash frontend
    wire s2_falsepred;
    wire[`XDEF] s2_falsepred_arch_pc;
    reg falsepred;
    reg[`XDEF] falsepred_arch_pc;

    wire toBPU_squash = i_squash_vld || falsepred;
    wire[`XDEF] toBPU_squash_arch_pc = i_squash_vld ? i_squashInfo.arch_pc : falsepred_arch_pc;

    wire toBPU_update_vld;
    wire toFTQ_update_finished;
    BPupdateInfo_t toBPU_updateInfo;
    wire toBPU_ftq_rdy;
    wire toFTQ_pred_vld;
    ftqInfo_t toFTQ_pred_ftqInfo;
    BPU u_BPU(
        .clk               ( clk ),
        .rst               ( rst ),
        .i_squash_vld      ( toBPU_squash ),
        .i_squash_arch_pc  ( toBPU_squash_arch_pc ),

        .i_update_vld      ( toBPU_update_vld      ),
        .o_update_finished ( toFTQ_update_finished ),
        .i_BPupdateInfo    ( toBPU_updateInfo      ),

        .i_ftq_rdy         ( toBPU_ftq_rdy      ),
        .o_pred_vld        ( toFTQ_pred_vld     ),
        .o_pred_ftqInfo    ( toFTQ_pred_ftqInfo )
    );


    reg stall_dueto_pcMisaligned;

    wire toIcache_req;
    ftqIdx_t toIcache_ftqIdx;
    wire toFTQ_icache_rdy;
    ftq2icacheInfo_t toIcache_info;
    // need to recovery ftq pred_ptr and fetch_ptr
    ftqIdx_t recovery_ftqIdx;
    branchwbInfo_t preDecwbInfo;
    FTQ u_FTQ(
        .clk                    ( clk ),
        .rst                    ( rst ),

        .i_squash_vld           ( i_squash_vld ),
        .i_squashInfo           ( i_squashInfo ),

        .i_stall                ( i_backend_stall  ),
        .i_falsepred            ( falsepred        ),
        .i_recovery_idx         ( recovery_ftqIdx  ),
        .i_preDecodewbInfo      ( preDecwbInfo      ),

        .i_pred_req             ( toFTQ_pred_vld     ),
        .o_ftq_rdy              ( toBPU_ftq_rdy      ),
        .i_pred_ftqInfo         ( toFTQ_pred_ftqInfo ),

        .o_bpu_update           ( toBPU_update_vld      ),
        .i_bpu_update_finished  ( toFTQ_update_finished ),
        .o_BPUupdateInfo        ( toBPU_updateInfo      ),

        .o_icache_fetch_req     ( toIcache_req    ),
        .o_icache_fetch_ftqIdx  ( toIcache_ftqIdx ),
        .i_icache_fetch_rdy     ( stall_dueto_pcMisaligned ? 0 : if_core_fetch.gnt     ),
        .o_icache_fetchInfo     ( toIcache_info   ),

        .i_read_ftqIdx          ( i_read_ftqIdx       ),
        .o_read_ftqStartAddr    ( o_read_ftqStartAddr ),
        .o_read_ftqNextAddr     ( o_read_ftqNextAddr  ),

        .i_backend_branchwb_vld ( i_branchwb_vld ),
        .i_backend_branchwbInfo ( i_branchwbInfo ),

        .i_commit_vld           ( i_commit_vld    ),
        .i_commit_ftqIdx        ( i_commit_ftqIdx )
    );

/****************************************************************************************************/
// icache port
// 3 stage icache
/****************************************************************************************************/
    wire pcMisaligned = toIcache_info.startAddr[0] == 1;

    assign if_core_fetch.req = toIcache_req;
    assign if_core_fetch.get2 = 1;
    assign if_core_fetch.addr = toIcache_info.startAddr[`BLK_RANGE];

    wire[`WDEF(`FTB_PREDICT_WIDTH/2)] validInst_vec;
    wire[`WDEF(`FTB_PREDICT_WIDTH/2)] fetched_inst_OH;// which region is a valid inst
    /* verilator lint_off UNOPTFLAT */
    wire[`WDEF(`FTB_PREDICT_WIDTH/2)] fetched_32i_OH;// which region is a 32bit inst

    reg s1_fetch_vld;
    ftqIdx_t s1_ftqIdx;
    reg[`XDEF] s1_startAddr;
    reg[`XDEF] s1_nextAddr;
    reg[`SDEF(`FTB_PREDICT_WIDTH)] s1_fetchblock_size;
    reg s1_predTaken;

    reg s2_fetch_vld;
    ftqIdx_t s2_ftqIdx;
    reg[`WDEF($clog2(`CACHELINE_SIZE))] s2_start_shift;
    reg[`XDEF] s2_startAddr;
    reg[`XDEF] s2_nextAddr;
    reg[`SDEF(`FTB_PREDICT_WIDTH)] s2_max_inst_num;
    reg s2_predTaken;
    reg[`XDEF] s2_inst_pcs[`FTB_PREDICT_WIDTH/2];
    reg[`XDEF] s2_reordered_inst_pcs[`FTB_PREDICT_WIDTH/2];
    branchwbInfo_t s2_preDecwbInfo;

    // generate new fetch entry
    ftqIdx_t s3_ftqIdx;
    wire[`WDEF(`FTB_PREDICT_WIDTH/2)] reordered_inst_OH;
    ftqOffset_t reordered_ftqOffset[`FTB_PREDICT_WIDTH/2];
    wire[`IDEF] reordered_insts[`FTB_PREDICT_WIDTH/2];

    reg[`WDEF(`FTB_PREDICT_WIDTH/2)] new_inst_vld;
    fetchEntry_t new_inst[`FTB_PREDICT_WIDTH/2];

    wire[`WDEF(`FTB_PREDICT_WIDTH/2)] new_inst_vld_wire;
    assign new_inst_vld_wire = stall_dueto_pcMisaligned ? 1 : ((if_core_fetch.rsp && s2_fetch_vld) ? reordered_inst_OH : 0);
    always_ff @( posedge clk ) begin
        int fa;
        if (rst || i_squash_vld || falsepred) begin
            new_inst_vld <= 0;
            s1_fetch_vld <= 0;
            s2_fetch_vld <= 0;
            stall_dueto_pcMisaligned <= 0;
            falsepred <= 0;
        end
        else begin
            // s0: ftq send fetch request

            // s1:
            s1_fetch_vld <= toIcache_req && if_core_fetch.gnt&& (!pcMisaligned) && (!i_backend_stall);
            stall_dueto_pcMisaligned <= toIcache_req ? pcMisaligned : 0;
            if (!i_backend_stall) begin
                s1_ftqIdx <= toIcache_ftqIdx;
            end
            s1_startAddr <= toIcache_info.startAddr;
            s1_nextAddr <= toIcache_info.nextAddr;
            s1_fetchblock_size <= toIcache_info.fetchBlock_size;
            s1_predTaken <= toIcache_info.taken;

            // s2: icache output 2 cachelines, do preDecode
            s2_fetch_vld <= s1_fetch_vld && (!i_backend_stall);
            if (!i_backend_stall) begin
                s2_ftqIdx <= s1_ftqIdx;
            end
            s2_startAddr <= s1_startAddr;
            s2_nextAddr <= s1_nextAddr;
            s2_start_shift <= s1_startAddr[$clog2(`CACHELINE_SIZE)-1:0];
            s2_max_inst_num <= (s1_fetchblock_size>>1); // if no RVC, should right shift 2
            s2_predTaken <= s1_predTaken;
            // assert(s2_fetch_vld ? s2_max_inst_num <= (`FTB_PREDICT_WIDTH/2) : 1);

            for (fa=0;fa<`FTB_PREDICT_WIDTH/2;fa=fa+1) begin
                s2_inst_pcs[fa] <= s1_startAddr + fa * 2;
            end

            // s3: generate new fetchEntry. and check false predict
            s3_ftqIdx <= s2_ftqIdx;
            falsepred <= s2_falsepred;
            preDecwbInfo <= s2_preDecwbInfo;
            falsepred_arch_pc <= s2_falsepred_arch_pc;
            if (!i_backend_stall) begin
                count_fetchToBackend(funcs::count_one(new_inst_vld_wire));
                new_inst_vld <= new_inst_vld_wire;
                if (new_inst_vld_wire[0]) begin
                    fetch_block(s2_startAddr, predecInfo_end.fallthru, (s2_falsepred ? s2_falsepred_arch_pc : s2_nextAddr), s2_falsepred);
                end
                for (fa = 0; fa < `FETCH_WIDTH; fa=fa+1) begin
                    if (new_inst_vld_wire[fa]) begin
                        new_inst[fa] <= '{
                            inst        : reordered_insts[fa],
                            ftq_idx     : s2_ftqIdx,
                            ftqOffset   : reordered_ftqOffset[fa],
                            foldpc      : (s2_reordered_inst_pcs[fa] >> 1),
                            has_except  : stall_dueto_pcMisaligned,
                            except      : rv_trap_t::pcMisaligned,

                            instmeta    : build_instmeta(s2_reordered_inst_pcs[fa], reordered_insts[fa])
                        };
                    end
                end
            end
        end
    end

    assign recovery_ftqIdx =
    s2_fetch_vld ? s2_ftqIdx :
    s1_fetch_vld ? s1_ftqIdx :
    toIcache_ftqIdx;

    wire[`WDEF(`CACHELINE_SIZE*8*2)] icacheline_merge;//s2
    assign icacheline_merge = ({if_core_fetch.line1, if_core_fetch.line0} >> (s2_start_shift*8));

    preDecInfo_t predecInfo[`FTB_PREDICT_WIDTH/2];
    preDecInfo_t predecInfo_end; // s2
    logic[`SDEF(`FTB_PREDICT_WIDTH/2)] fallthruOffset_end;

    // if nonbranch falsepred, set branchtype = condbranch, ste not taken
    assign s2_preDecwbInfo = '{
        branch_type     : predecInfo_end.isDirect ? BranchType::isDirect : predecInfo_end.isIndirect ? BranchType::isIndirect : BranchType::isCond,
        rob_idx : 0, // dont care
        ftq_idx         : s2_ftqIdx,
        has_mispred     : 1,
        branch_taken    : (predecInfo_end.simplePredNPC == predecInfo_end.target),
        fallthruOffset  : fallthruOffset_end,
        target_pc       : predecInfo_end.target,
        branch_npc      : predecInfo_end.simplePredNPC
    };

    // if predecInfo_end == jal, s2_nextAddr must equal to jal target
    // if predecInfo_end == bxx, s2_nextAddr must equal to bxx target or fallthru
    // if predecInfo_end == nonBranch, s2_nextAddr must equal to fallthru
    // if fetched_inst_OH > fetched_inst_mask is falsepred

    wire inst_leak;

    assign s2_falsepred = s2_fetch_vld &&
    (!(predecInfo_end.isDirect   ? predecInfo_end.target == s2_nextAddr :
    predecInfo_end.isCond       ? ((predecInfo_end.target == s2_nextAddr) || (predecInfo_end.fallthru == s2_nextAddr)) :
    predecInfo_end.isIndirect   ? 1 :
    (predecInfo_end.fallthru == s2_nextAddr))
    || inst_leak);

    assign s2_falsepred_arch_pc = s2_preDecwbInfo.branch_npc; // should equal FTQ's next pc

    wire[`IDEF] fetched_insts[`FTB_PREDICT_WIDTH/2];//s2
    ftqOffset_t temp_ftqOffset[`FTB_PREDICT_WIDTH/2];
    wire[`WDEF(`FTB_PREDICT_WIDTH/2)] fetched_inst_mask; // 1 | 1 | 1(jal or jalr) | 0 | 0
    wire[`WDEF(`FTB_PREDICT_WIDTH/2)] predec_invalidbranch;
    generate
        for(i=0; i < `FTB_PREDICT_WIDTH/2; i=i+1) begin : gen_for
            assign fetched_insts[i] = {icacheline_merge[i*16 + 31 : i*16]};
            if (i == 0) begin : gen_if
                assign fetched_32i_OH[i] = fetched_insts[i][1:0]==2'b11;
                assign fetched_inst_OH[i] = 1;
                assign fetched_inst_mask[i] = 1;
            end
            else begin : gen_else
                assign fetched_32i_OH[i] = (fetched_insts[i][1:0]==2'b11) && (!fetched_32i_OH[i-1]);
                assign fetched_inst_OH[i] = (fetched_32i_OH[i-1] ? 0 : 1) && (i < s2_max_inst_num);
                // one fetch block should only have one branch inst
                assign fetched_inst_mask[i] = (!(predecInfo[i-1].isBr)) && fetched_inst_mask[i-1];
            end

            preDecode u_preDecode(
                .i_inst           ( fetched_insts[i] ),
                .i_pc             ( s2_inst_pcs[i]     ),
                .o_info           ( predecInfo[i] )
            );
        end
    endgenerate

    assign inst_leak = fetched_inst_OH > fetched_inst_mask;

    generate
        for(i=0;i<`FTB_PREDICT_WIDTH/2;i=i+1) begin:gen_for
            assign temp_ftqOffset[i] = 2 * i;
        end
    endgenerate

    assign validInst_vec = fetched_inst_OH & fetched_inst_mask;

    // preDecode and check falsepred
    always_comb begin
        int ca;
        predecInfo_end = predecInfo[0];
        fallthruOffset_end = temp_ftqOffset[0] + (fetched_32i_OH[0] ? 4 : 2);
        for (ca=0; ca<`FTB_PREDICT_WIDTH/2; ca=ca+1) begin
            if (validInst_vec[ca]) begin
                predecInfo_end = predecInfo[ca];
                fallthruOffset_end = temp_ftqOffset[ca] + (fetched_32i_OH[ca] ? 4 : 2);
            end
        end
    end

    reorder
    #(
        .dtype ( logic[`IDEF]         ),
        .NUM   ( `FTB_PREDICT_WIDTH/2 )
    )
    u_reorder_0(
        .i_data_vld      ( validInst_vec      ),
        .i_datas         ( fetched_insts        ),
        .o_data_vld      ( reordered_inst_OH    ),
        .o_reorder_datas ( reordered_insts      )
    );

    reorder
    #(
        .dtype ( logic[`XDEF]         ),
        .NUM   ( `FTB_PREDICT_WIDTH/2 )
    )
    u_reorder_2(
        .i_data_vld      ( validInst_vec      ),
        .i_datas         ( s2_inst_pcs        ),
        .o_reorder_datas ( s2_reordered_inst_pcs      )
    );

    reorder
    #(
        .dtype ( ftqOffset_t          ),
        .NUM   ( `FTB_PREDICT_WIDTH/2 )
    )
    u_reorder_1(
        .i_data_vld      ( validInst_vec      ),
        .i_datas         ( temp_ftqOffset       ),
        .o_reorder_datas ( reordered_ftqOffset  )
    );

    assign o_fetch_inst_vld = new_inst_vld;
    assign o_fetch_inst = new_inst;

endmodule


