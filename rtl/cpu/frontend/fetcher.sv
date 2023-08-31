`include "frontend_define.svh"
`include "funcs.svh"



// backend may read/write some info from frontend
// one instruction pc used for branch and trap
// branch writeback info: branch offset in ftq, branch target pc, branch mispred, branch taken



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

    wire toBPU_update_vld;
    wire toFTQ_update_finished;
    BPupdateInfo_t toBPU_updateInfo;

    wire toBPU_ftq_rdy;
    wire toFTQ_pred_vld;
    ftqInfo_t toFTQ_pred_ftqInfo;
    BPU u_BPU(
        .clk               ( clk ),
        .rst               ( rst ),
        .i_squash_vld      ( i_squash_vld ),
        .i_squashInfo      ( i_squashInfo ),

        .i_update_vld      ( toBPU_update_vld      ),
        .o_update_finished ( toFTQ_update_finished ),
        .i_BPupdateInfo    ( toBPU_updateInfo      ),

        .i_ftq_rdy         ( toBPU_ftq_rdy      ),
        .o_pred_vld        ( toFTQ_pred_vld     ),
        .o_pred_ftqInfo    ( toFTQ_pred_ftqInfo )
    );


    reg stall_dueto_pcUnaligned;

    wire toIcache_req;
    ftqIdx_t toIcache_ftqIdx;
    wire toFTQ_icache_rdy;
    ftq2icacheInfo_t toIcache_info;

    ftqIdx_t stall_recovery_ftqIdx;
    FTQ u_FTQ(
        .clk                    ( clk ),
        .rst                    ( rst ),

        .i_squash_vld           ( i_squash_vld ),
        .i_squashInfo           ( i_squashInfo ),

        .i_stall                ( i_backend_stall  ),
        .i_recovery_idx         ( stall_recovery_ftqIdx  ),

        .i_pred_req             ( toFTQ_pred_vld     ),
        .o_ftq_rdy              ( toBPU_ftq_rdy      ),
        .i_pred_ftqInfo         ( toFTQ_pred_ftqInfo ),

        .o_bpu_update           ( toBPU_update_vld      ),
        .i_bpu_update_finished  ( toFTQ_update_finished ),
        .o_BPUupdateInfo        ( toBPU_updateInfo      ),

        .o_icache_fetch_req     ( toIcache_req    ),
        .o_icache_fetch_ftqIdx  ( toIcache_ftqIdx ),
        .i_icache_fetch_rdy     ( stall_dueto_pcUnaligned ? 0 : if_core_fetch.gnt     ),
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
    wire pcUnaligned = toIcache_info.startAddr[0] == 1;

    assign if_core_fetch.req = toIcache_req;
    assign if_core_fetch.get2 = toIcache_info.startAddr[$clog2(`CACHELINE_SIZE)-1 : 0] >= `CACHELINE_SIZE/2;
    assign if_core_fetch.addr = toIcache_info.startAddr[`BLK_RANGE];

    reg s1_fetch_vld;
    ftqIdx_t s1_ftqIdx;
    reg[`XDEF] s1_startAddr;
    reg[`SDEF(`FTB_PREDICT_WIDTH)] s1_fetchblock_size;

    reg s2_fetch_vld;
    ftqIdx_t s2_ftqIdx;
    reg[`WDEF($clog2(`CACHELINE_SIZE))] s2_start_shift;
    reg[`SDEF(`FTB_PREDICT_WIDTH)] s2_max_inst_num;

    wire[`WDEF(`FTB_PREDICT_WIDTH/2)] fetched_inst_OH, reordered_inst_OH;// which region is a valid inst
    /* verilator lint_off UNOPTFLAT */
    wire[`WDEF(`FTB_PREDICT_WIDTH/2)] fetched_32i_OH;// which region is a 32bit inst
    ftqOffset_t reordered_ftqOffset[`FTB_PREDICT_WIDTH/2];



    // generate new fetch entry
    reg[`WDEF(`FTB_PREDICT_WIDTH/2)] new_inst_vld;
    fetchEntry_t new_inst[`FTB_PREDICT_WIDTH/2];
    always_ff @( posedge clk ) begin
        int fa;
        if (rst || i_squash_vld) begin
            new_inst_vld <= 0;
            s1_fetch_vld <= 0;
            s2_fetch_vld <= 0;
            stall_dueto_pcUnaligned <= 0;
        end
        else begin
            // s1
            s1_fetch_vld <= toIcache_req && if_core_fetch.gnt&& (!pcUnaligned)  && (!i_backend_stall);
            stall_dueto_pcUnaligned <= toIcache_req ? pcUnaligned : 0;
            if (!i_backend_stall) begin
                s1_ftqIdx <= toIcache_ftqIdx;
            end

            s1_startAddr <= toIcache_info.startAddr;
            s1_fetchblock_size <= toIcache_info.fetchBlock_size;

            // s2: icache output 2 cachelines
            s2_fetch_vld <= s1_fetch_vld && (!i_backend_stall) ;
            if (!i_backend_stall) begin
                s2_ftqIdx <= s1_ftqIdx;
            end
            s2_start_shift <= s1_startAddr[$clog2(`CACHELINE_SIZE)-1:0];
            s2_max_inst_num <= (s1_fetchblock_size>>1); // if no RVC, should left shift 2

            // s3: cacheline shift and align, generate new fetchEntry
            if (!i_backend_stall) begin
                new_inst_vld <= stall_dueto_pcUnaligned ? 1 : ((if_core_fetch.rsp && s2_fetch_vld) ? reordered_inst_OH : 0);
                for (fa = 0; fa < `FETCH_WIDTH; fa=fa+1) begin
                    new_inst[fa] <= '{
                        inst        : reordered_insts[fa],
                        ftq_idx     : s2_ftqIdx,
                        ftqOffset   : reordered_ftqOffset[fa],
                        has_except  : stall_dueto_pcUnaligned,
                        except      : rv_trap_t::pcUnaligned
                    };
                end
            end
        end
    end
    assign stall_recovery_ftqIdx = s2_fetch_vld ? s2_ftqIdx : s1_fetch_vld ? s1_ftqIdx : toIcache_ftqIdx;


    wire[`WDEF(`CACHELINE_SIZE*8*2)] icacheline_merge;
    assign icacheline_merge = ({if_core_fetch.line1, if_core_fetch.line0} >> (s2_start_shift*8));

    wire[`IDEF] fetched_insts[`FTB_PREDICT_WIDTH/2];
    wire[`IDEF] reordered_insts[`FTB_PREDICT_WIDTH/2];

    generate
        for(i=0; i < `FTB_PREDICT_WIDTH/2; i=i+1) begin:gen_for
            assign fetched_insts[i] = {icacheline_merge[i*16 + 31 : i*16]};
            if (i == 0) begin : gen_if
                assign fetched_32i_OH[i] = fetched_insts[i][1:0]==2'b11;
                assign fetched_inst_OH[i] = 1;
            end
            else begin : gen_else
                assign fetched_32i_OH[i] = (fetched_insts[i][1:0]==2'b11) && (!fetched_32i_OH[i-1]);
                assign fetched_inst_OH[i] = (fetched_32i_OH[i-1] ? 0 : 1) && (i < s2_max_inst_num);
            end
        end
    endgenerate


    reorder
    #(
        .dtype ( logic[`IDEF]         ),
        .NUM   ( `FTB_PREDICT_WIDTH/2 )
    )
    u_reorder_0(
        .i_data_vld      ( fetched_inst_OH      ),
        .i_datas         ( fetched_insts        ),
        .o_data_vld      ( reordered_inst_OH    ),
        .o_reorder_datas ( reordered_insts      )
    );

    ftqOffset_t temp_ftqOffset[`FTB_PREDICT_WIDTH/2];
    generate
        for(i=0;i<`FTB_PREDICT_WIDTH/2;i=i+1) begin:gen_for
            assign temp_ftqOffset[i] = 2 * i;
        end
    endgenerate
    reorder
    #(
        .dtype ( ftqOffset_t          ),
        .NUM   ( `FTB_PREDICT_WIDTH/2 )
    )
    u_reorder_1(
        .i_data_vld      ( fetched_inst_OH      ),
        .i_datas         ( temp_ftqOffset       ),
        .o_data_vld      (),
        .o_reorder_datas ( reordered_ftqOffset  )
    );

    assign o_fetch_inst_vld = new_inst_vld;
    assign o_fetch_inst = new_inst;

    wire AAA_s0_vld = toIcache_req;
    ftqIdx_t AAA_s0_ftqIdx = toIcache_ftqIdx;
    wire AAA_s1_vld = s1_fetch_vld;
    ftqIdx_t AAA_s1_ftqIdx = s1_ftqIdx;
    wire AAA_s2_vld = s2_fetch_vld;
    ftqIdx_t AAA_s2_ftqIdx = s2_ftqIdx;
    wire AAA_s3_vld = |o_fetch_inst_vld;
    ftqIdx_t AAA_s3_ftqIdx = new_inst[0].ftq_idx;
    wire has_fetched = (!i_backend_stall) && (|o_fetch_inst_vld);

    int AAA_has_fetched_num;
    always_ff @( posedge clk ) begin : blockName
        if(rst) begin
            AAA_has_fetched_num <=0;
        end
        else begin
            if (has_fetched) begin
                AAA_has_fetched_num <= AAA_has_fetched_num + funcs::count_one(o_fetch_inst_vld);
            end
        end
    end

endmodule


