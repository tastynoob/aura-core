`include "frontend_define.svh"


// BPU -> FTQ -> backend

// FTB only can predict short jump branch
// we meed to implement BTB
// TODO: remove counter from FTB, use the independent component to predict conditional branch
import "DPI-C" function void bp_hit_at(uint64_t n);
import "DPI-C" function void bpu_predict_block(
    uint64_t startAddr,
    uint64_t endAddr,
    uint64_t nextAddr,
    uint64_t select
);
import "DPI-C" function void count_bpuGeneratedBlock(uint64_t n);
import "DPI-C" function void bpu_update_arch_gbh(
    logic [`WDEF(`BRHISTORYLENGTH)] gbh,
    uint64_t len
);
import "DPI-C" function void bpu_update_spec_gbh(
    logic [`WDEF(`BRHISTORYLENGTH)] gbh,
    uint64_t len,
    uint64_t squash
);

module BPU (
    input wire clk,
    input wire rst,

    input wire i_squash_vld,
    input wire [`XDEF] i_squash_arch_pc,

    input wire i_commit_vld,
    output wire o_update_finished,
    input BPupdateInfo_t i_BPupdateInfo,

    // predict output -> ftq
    input wire i_ftq_rdy,
    output wire o_pred_vld,
    output BPInfo_t o_pred_ftqInfo
);
    wire squash_dueToBackend = i_squash_vld;
    wire squash_vld;

    reg [`XDEF] base_pc, s1_base_pc, s2_base_pc;
    wire pred_accept;
    wire pred_continue;
    assign pred_continue = i_ftq_rdy;
    assign pred_accept = (o_pred_vld && i_ftq_rdy);
    wire lookup_req = 1;

    /****************************************************************************************************/
    // branch history
    /****************************************************************************************************/
    wire commit_finish;
    assign commit_finish = (i_commit_vld && o_update_finished);

    reg [`WDEF(`BRHISTORYLENGTH)] spec_gbh;
    wire [`WDEF(`BRHISTORYLENGTH)] nxt_spec_gbh;

    reg [`WDEF(`BRHISTORYLENGTH)] arch_gbh;
    wire [`WDEF(`BRHISTORYLENGTH)] nxt_arch_gbh;
    assign nxt_arch_gbh = {arch_gbh[`BRHISTORYLENGTH-2:0], i_BPupdateInfo.taken};
    always_ff @(posedge clk) begin
        if (rst) begin
            spec_gbh <= 0;
            arch_gbh <= 0;
        end
        else begin
            if (commit_finish) begin
                arch_gbh <= nxt_arch_gbh;
                bpu_update_arch_gbh(nxt_arch_gbh, `BRHISTORYLENGTH);
            end

            if (squash_dueToBackend) begin
                if (commit_finish) begin
                    spec_gbh <= nxt_arch_gbh;
                    bpu_update_spec_gbh(nxt_arch_gbh, `BRHISTORYLENGTH, 1);
                end
                else begin
                    spec_gbh <= arch_gbh;
                    bpu_update_spec_gbh(arch_gbh, `BRHISTORYLENGTH, 1);
                end
            end
            else if (s0_ubtb_hit) begin
                spec_gbh <= nxt_spec_gbh;
                bpu_update_spec_gbh(nxt_spec_gbh, `BRHISTORYLENGTH, 0);
            end
        end
    end

    assign o_update_finished = i_commit_vld;

    /****************************************************************************************************/
    // predicted result select
    /****************************************************************************************************/
    wire [`WDEF(2)] s0_bpSelect, s1_bpSelect, s2_bpSelect;

    // 0: ubtb
    // 1: tage
    // 2: ras
    // 3: btb

    assign s0_bpSelect = 0;

    reg s1_req, s2_req;
    always_ff @(posedge clk) begin
        if (rst) begin
            s1_req <= 0;
            s2_req <= 0;
        end
        else begin
            if (squash_vld) begin
                s1_req <= 0;
                s2_req <= 0;
            end
            else if (pred_continue) begin
                s1_req <= lookup_req;
                s2_req <= s1_req;
            end
        end
    end

    /****************************************************************************************************/
    // uBTB
    /****************************************************************************************************/
    wire update_ubtb;
    uBTBInfo_t ubtbUpdateInfo;
    assign update_ubtb = i_commit_vld;
    assign ubtbUpdateInfo = '{
            hit          : 0,  // ignore
            taken        : i_BPupdateInfo.taken,
            fallthruAddr : i_BPupdateInfo.fallthruAddr,
            targetAddr   : i_BPupdateInfo.targetAddr,
            nextAddr     : 0,  // ignore
            branch_type  : i_BPupdateInfo.branch_type
        };

    assign nxt_spec_gbh = {spec_gbh[`BRHISTORYLENGTH-2:0], ubtbInfo.taken};

    reg s1_ubtb_use, s2_ubtb_use;
    uBTBInfo_t ubtbInfo, s1_ubtbInfo, s2_ubtbInfo;
    uBTB #(
        .DEPTH(32)
    ) u_uBTB (
        .clk(clk),
        .rst(rst),

        .i_lookup_pc(base_pc),
        .i_gbh      (spec_gbh),
        .o_uBTBInfo (ubtbInfo),

        .i_update    (update_ubtb),
        .i_update_pc (i_BPupdateInfo.startAddr),
        .i_arch_gbh  (arch_gbh),
        .i_updateInfo(ubtbUpdateInfo)
    );

    wire s0_ubtb_hit = ubtbInfo.hit;
    wire s0_ubtb_taken = ubtbInfo.taken;
    wire [`XDEF] s0_ubtb_targetAddr = ubtbInfo.targetAddr;
    wire [`XDEF] s0_ubtb_fallthruAddr = ubtbInfo.fallthruAddr;
    wire [`XDEF] s0_ubtb_npc = ubtbInfo.nextAddr;

    always_ff @(posedge clk) begin
        if (rst) begin
            s1_ubtb_use <= 0;
            s2_ubtb_use <= 0;
        end
        else begin
            if (squash_vld) begin
                s1_ubtb_use <= 0;
                s2_ubtb_use <= 0;
            end
            else if (pred_continue) begin
                s1_ubtb_use <= s0_ubtb_hit;
                s2_ubtb_use <= s1_ubtb_use;

                s1_ubtbInfo <= ubtbInfo;
                s2_ubtbInfo <= s1_ubtbInfo;
            end
        end
    end


    /****************************************************************************************************/
    // FTB (closed)
    // when FTB updating, BPU will skip FTB's predict result
    /****************************************************************************************************/
    wire ftb_lookup_gnt;
    wire s1_ftb_lookup_hit, s1_ftb_lookup_hit_rdy;
    ftbInfo_t s2_ftb_lookup_info;
    FTB u_FTB (
        .clk         (clk),
        .rst         (rst),
        .i_squash_vld(squash_vld),

        .i_lookup_req    (lookup_req),
        .o_lookup_gnt    (ftb_lookup_gnt),
        .i_lookup_pc     (base_pc),
        .o_lookup_hit    (s1_ftb_lookup_hit),      // s1
        .o_lookup_hit_rdy(s1_ftb_lookup_hit_rdy),  // s1
        .o_lookup_ftbInfo(s2_ftb_lookup_info),     // s2

        .i_update_req     (0),
        .o_update_finished(),
        .i_update_pc      (0),
        .i_update_ftbInfo (0)
    );

    reg s2_ftb_lookup_hit;
    reg s2_ftb_lookup_hit_rdy;
    reg s2_ftb_use;  // ftb lookup hit

    wire [`XDEF] s2_ftb_fallthruAddr = (s2_ftb_use ? ftbFuncs::calcFallthruAddr(
        s2_base_pc, s2_ftb_lookup_info
    ) : s1_base_pc);
    wire [`XDEF] s2_ftb_targetAddr = ftbFuncs::calcTargetAddr(s2_base_pc, s2_ftb_lookup_info);

    always_ff @(posedge clk) begin
        if (rst) begin
            s2_ftb_use <= 0;
            s2_ftb_lookup_hit_rdy <= 0;
        end
        else begin
            if (squash_vld) begin
                s2_ftb_use <= 0;
                s2_ftb_lookup_hit <= 0;
                s2_ftb_lookup_hit_rdy <= 0;
            end
            else if (pred_continue) begin
                s2_ftb_use <= (s1_ftb_lookup_hit_rdy && s1_ftb_lookup_hit && s1_req);
                s2_ftb_lookup_hit <= s1_ftb_lookup_hit && s1_req;
                s2_ftb_lookup_hit_rdy <= s1_ftb_lookup_hit_rdy && s1_req;
            end
        end
    end

    /****************************************************************************************************/
    // get the lookup info and calcuate the next pc
    /****************************************************************************************************/

    always_ff @(posedge clk) begin
        if (rst) begin
            base_pc <= `INIT_PC;
        end
        else begin
            if (squash_dueToBackend) begin
                base_pc <= i_squash_arch_pc;
            end
            else if (s2_ftb_use) begin
                // base_pc <= s2_ftb_npc;
                assert (false);
            end
            else if (pred_continue) begin
                if (s0_ubtb_hit) begin
                    base_pc <= s0_ubtb_npc;
                end
                else begin
                    base_pc <= base_pc + (`FTB_PREDICT_WIDTH);
                end
                s1_base_pc <= base_pc;
                s2_base_pc <= s1_base_pc;
            end

            if (pred_accept) begin
                if (s2_ubtb_use) begin
                    bp_hit_at(1);
                end

                count_bpuGeneratedBlock((s2_base_fallthruAddr - s2_base_pc));
                bpu_predict_block(s2_base_pc, s2_base_fallthruAddr, s2_base_npc, (s2_ubtb_use ? 1 : 0));
                assert (s2_base_fallthruAddr > s2_base_pc);
            end
        end
    end
    // when lookup hit in ftb , we need to squash
    assign squash_vld = squash_dueToBackend || s2_ftb_use;

    /****************************************************************************************************/
    // send predict result to ftq
    /****************************************************************************************************/
    wire [`XDEF] s2_base_fallthruAddr;
    assign s2_base_fallthruAddr = s2_ubtb_use ? s2_ubtbInfo.fallthruAddr : s1_base_pc;

    wire [`XDEF] s2_base_npc;
    assign s2_base_npc = s2_ubtb_use ? s2_ubtbInfo.nextAddr : s2_base_fallthruAddr;

    wire s2_base_taken = s2_ubtb_use ? s2_ubtbInfo.taken : 0;
    wire [`XDEF] s2_base_target = s2_ubtb_use ? s2_ubtbInfo.targetAddr : 0;


    assign o_pred_vld = s2_req;

    // the fetch range: [start, end)
    assign o_pred_ftqInfo = '{
            startAddr   : s2_base_pc,
            endAddr     : s2_base_fallthruAddr,
            nextAddr    : s2_base_npc,
            taken       : s2_base_taken,
            targetAddr  : s2_ubtbInfo.targetAddr,
            // ubtb meta
            hit_on_ubtb :
            s2_ubtb_use,
            // ftb meta
            hit_on_ftb  :
            0,
            branch_type : BranchType::isNone
        };


endmodule

