`include "backend_define.svh"








module virtualLSQ #(
    parameter int INPORTS        = `MEMDQ_DISP_WID,
    parameter int LD_ISSUE_WIDTH = 2,
    parameter int ST_ISSUE_WIDTH = 2,
    parameter int LD_COMMIT_WIDTH = `COMMIT_WIDTH,
    parameter int ST_COMMIT_WIDTH = `COMMIT_WIDTH
    // INPORTS should be equal to LD_ISSUE_WIDTH + ST_ISSUE_WIDTH
) (
    input wire clk,
    input wire rst,

    output wire o_can_enq,
    input wire [`WDEF(INPORTS)] i_enq_req,
    input microOp_t i_enq_inst[INPORTS],

    output lqIdx_t o_alloc_lqIdx[INPORTS],
    output sqIdx_t o_alloc_sqIdx[INPORTS],

    input wire[`WDEF($clog2(`COMMIT_WIDTH))] i_ld_commit_num,
    input wire[`WDEF($clog2(`COMMIT_WIDTH))] i_st_commit_num
);
    genvar i;
    wire [`WDEF(INPORTS)] isLoad;
    wire [`WDEF(INPORTS)] isStore;
    wire [`SDEF(INPORTS)] enqLoadNum;
    wire [`SDEF(INPORTS)] enqStoreNum;
    generate
        for (i = 0; i < INPORTS; i = i + 1) begin
            assign isLoad[i] = o_can_enq && i_enq_req[i] && (i_enq_inst[i].issueQueId == `LDUIQ_ID);
            assign isStore[i] = o_can_enq && i_enq_req[i] && (i_enq_inst[i].issueQueId == `STUIQ_ID);
        end
    endgenerate
    count_one #(
        .WIDTH(INPORTS)
    ) u_count_one0 (
        .i_a  (isLoad),
        .o_sum(enqLoadNum)
    );
    count_one #(
        .WIDTH(INPORTS)
    ) u_count_one1 (
        .i_a  (isStore),
        .o_sum(enqStoreNum)
    );

    wire [`WDEF($clog2(`COMMIT_WIDTH))] deqLoadNum = i_ld_commit_num;
    wire [`WDEF($clog2(`COMMIT_WIDTH))] deqStoreNum = i_st_commit_num;


    lqIdx_t lqhead[INPORTS];
    sqIdx_t sqhead[INPORTS];
    reg [`SDEF(`LQSIZE)] ldNum;
    reg [`SDEF(`SQSIZE)] stNum;

    assign o_can_enq = (ldNum <= (`LQSIZE - LD_ISSUE_WIDTH)) && (stNum <= (`SQSIZE - ST_ISSUE_WIDTH));

    always_ff @(posedge clk) begin
        int fa;
        if (rst) begin
            ldNum <= 0;
            stNum <= 0;
            for (fa = 0; fa < INPORTS; fa = fa + 1) begin
                lqhead[fa] <= fa;
                sqhead[fa] <= fa;
            end
        end
        else begin
            ldNum <= ldNum + enqLoadNum - deqLoadNum;
            stNum <= stNum + enqStoreNum - deqStoreNum;

            for (fa = 0; fa < INPORTS; fa = fa + 1) begin
                lqhead[fa].idx <= (lqhead[fa].idx + enqLoadNum) < `LQSIZE ? (lqhead[fa].idx + enqLoadNum) : (lqhead[fa].idx + enqLoadNum - `LQSIZE);
                if ((lqhead[fa].idx + enqLoadNum) >= `LQSIZE) begin
                    lqhead[fa].flipped <= ~lqhead[fa].flipped;
                end
                sqhead[fa].idx <= (sqhead[fa].idx + enqStoreNum) < `SQSIZE ? (sqhead[fa].idx + enqStoreNum) : (sqhead[fa].idx + enqStoreNum - `SQSIZE);
                if ((sqhead[fa].idx + enqStoreNum) >= `SQSIZE) begin
                    sqhead[fa].flipped <= ~sqhead[fa].flipped;
                end
            end
        end
    end

/*
    inst    lqIdx   sqIdx
3   load    1       2
2   store   1       1
1   load    0       1
0   store   0       0
*/

    redirect #(
        .dtype (lqIdx_t),
        .NUM  (INPORTS)
    ) u_redirect0(
        .i_arch_vld       ( isLoad ),
        .i_arch_datas     ( lqhead ),
        .o_redirect_datas ( o_alloc_lqIdx )
    );

    redirect #(
        .dtype (sqIdx_t),
        .NUM  (INPORTS)
    ) u_redirect1(
        .i_arch_vld       ( isStore ),
        .i_arch_datas     ( sqhead ),
        .o_redirect_datas ( o_alloc_sqIdx )
    );

endmodule
