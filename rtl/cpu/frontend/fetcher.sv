`include "frontend_define.svh"




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
    input wire i_backend_rdy,
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

    FTQ u_FTQ(
        .clk                    ( clk ),
        .rst                    ( rst ),

        .i_squash_vld           ( i_squash_vld ),
        .i_squashInfo           ( i_squashInfo ),

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
    reg[`WDEF($clog2(`FTB_PREDICT_WIDTH))] s1_fetchblock_size;

    ftqIdx_t s2_ftqIdx;
    reg[`WDEF($clog2(`CACHELINE_SIZE))] s2_start_shift;
    reg[`WDEF($clog2(`FTB_PREDICT_WIDTH))] s2_end_offset;

    wire[`WDEF(`FTB_PREDICT_WIDTH/2)] fetched_inst_OH, reordered_inst_OH;// which region is a valid inst
    /* verilator lint_off UNOPTFLAT */
    wire[`WDEF(`FTB_PREDICT_WIDTH/2)] fetched_32i_OH;// which region is a 32bit inst
    wire[`IDEF] fetched_insts[`FTB_PREDICT_WIDTH/2], reordered_insts[`FTB_PREDICT_WIDTH/2];
    ftqOffset_t reordered_ftqOffset[`FTB_PREDICT_WIDTH/2];
    wire[`WDEF(`CACHELINE_SIZE*8*2)] icacheline_merge = ({if_core_fetch.line1, if_core_fetch.line0} >> (s2_start_shift*8));

    // generate new fetch entry
    reg[`WDEF(`FTB_PREDICT_WIDTH/2)] new_inst_vld;
    fetchEntry_t new_inst[`FTB_PREDICT_WIDTH/2];
    always_ff @( posedge clk ) begin
        int fa;
        if (rst) begin
            new_inst_vld <= 0;
            s1_fetch_vld <= 0;
            stall_dueto_pcUnaligned <= 0;
        end
        else begin
            // s1
            s1_fetch_vld <= toIcache_req && (!pcUnaligned) && if_core_fetch.gnt;
            stall_dueto_pcUnaligned <= toIcache_req ? pcUnaligned : 0;

            s1_ftqIdx <= toIcache_ftqIdx;
            s1_startAddr <= toIcache_info.startAddr;
            s1_fetchblock_size <= toIcache_info.fetchBlock_size;

            // s2: icache output 2 cachelines
            if (s1_fetch_vld && if_core_fetch.gnt) begin
                s2_ftqIdx <= s1_ftqIdx;
                s2_start_shift <= s1_startAddr[$clog2(`CACHELINE_SIZE)-1:0];
                s2_end_offset <= s1_fetchblock_size;
            end
            // s3: cacheline shift and align, generate new fetchEntry
            new_inst_vld <= stall_dueto_pcUnaligned ? 1 : (if_core_fetch.rsp ? reordered_inst_OH : 0);
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

    generate
        for(i=0; i < `FTB_PREDICT_WIDTH/2; i=i+1) begin:gen_for
            if (i == 0) begin : gen_if
                assign fetched_32i_OH[i] = icacheline_merge[i*16 + 1 : i*16]==2'b11;
                assign fetched_inst_OH[i] = 1;
            end
            else begin : gen_else
                assign fetched_32i_OH[i] = (icacheline_merge[i*16 + 1 : i*16]==2'b11) && (!fetched_32i_OH[i-1]);
                assign fetched_inst_OH[i] = fetched_32i_OH[i-1] ? 0 : 1;
            end
            assign fetched_insts[i] = {icacheline_merge[i*16 + 31 : i*16]};
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




endmodule


