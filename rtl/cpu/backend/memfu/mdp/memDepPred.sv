


`include "backend_define.svh"





module memDepPred (
    input wire clk,
    input wire rst,

    input wire i_stall,

    // insert new inst
    // rename stage, lookup SSIT
    input wire [`WDEF(`RENAME_WIDTH)] i_lookup_ssit_vld,
    input wire [`WDEF(`MEMDEP_FOLDPC_WIDTH)] i_foldpc[`RENAME_WIDTH],

    // dispatch stage check inst dep and insert store
    input wire [`WDEF(`RENAME_WIDTH)] i_insert_store,
    input robIdx_t i_allocated_robIdx[`RENAME_WIDTH],
    output wire [`WDEF(`RENAME_WIDTH)] o_shouldwait,
    output robIdx_t o_dep_robIdx[`RENAME_WIDTH],

    // store issued
    input wire [`WDEF(`STORE_ISSUE_WIDTH)] i_store_issued,
    input wire [`WDEF(`MEMDEP_FOLDPC_WIDTH)] i_issue_foldpc[`STORE_ISSUE_WIDTH],
    input robIdx_t i_store_robIdx[`STORE_ISSUE_WIDTH],

    // violation update
    input wire i_violation,
    input wire [`WDEF(`MEMDEP_FOLDPC_WIDTH)] i_vio_store_foldpc,
    input wire [`WDEF(`MEMDEP_FOLDPC_WIDTH)] i_vio_load_foldpc,

    // dispatch->IQ,  read busytable
    input robIdx_t i_read_robIdx[`MEMDQ_DISP_WID],
    output wire [`WDEF(`MEMDQ_DISP_WID)] o_memdep_rdy
);

    genvar i;

    logic [`WDEF(`ROB_SIZE)] nxt_rdy_bits;
    reg [`WDEF(`ROB_SIZE)] rdy_bits;

    always_ff @(posedge clk) begin
        int fa, fb;
        if (rst || i_violation) begin
            for (fa = 0; fa < `ROB_SIZE; fa = fa + 1) begin
                rdy_bits[fa] <= 1;
            end
        end
        else begin
            for (fa = 0; fa < `RENAME_WIDTH; fa = fa + 1) begin
                if (i_insert_store[fa]) begin
                    assert (rdy_bits[i_allocated_robIdx[fa].idx]);
                    rdy_bits[i_allocated_robIdx[fa].idx] <= 0;
                end
            end
            for (fa = 0; fa < `STORE_ISSUE_WIDTH; fa = fa + 1) begin
                if (i_store_issued[fa]) begin
                    assert (rdy_bits[i_store_robIdx[fa].idx] == 0);
                    rdy_bits[i_store_robIdx[fa].idx] <= 1;

                    // assert check
                    for (fb = 0; fb < `RENAME_WIDTH; fb = fb + 1) begin
                        if (i_insert_store[fb]) begin
                            assert (i_allocated_robIdx[fa].idx != i_store_robIdx[fa]);
                        end
                    end
                end
            end
        end
    end

    always_comb begin
        int ca;
        nxt_rdy_bits = rdy_bits;
        for (ca = 0; ca < `STORE_ISSUE_WIDTH; ca = ca + 1) begin
            if (i_store_issued[ca]) begin
                nxt_rdy_bits[i_store_robIdx[ca].idx] = 1;
            end
        end
    end

    generate
        for (i = 0; i < `MEMDQ_DISP_WID; i = i + 1) begin
            assign o_memdep_rdy[i] = nxt_rdy_bits[i_read_robIdx[i].idx];
        end
    endgenerate



`ifdef ENABLE_MEMPRED
    StoreSet #(
        .SSIT_SIZE(`SSIT_SIZE),
        .LFST_SIZE(`LFST_SIZE)
    ) u_StoreSet (
        .clk    (clk),
        .rst    (rst),
        .i_stall(i_stall),

        .i_lookup_ssit_vld(i_lookup_ssit_vld),
        .i_foldpc         (i_foldpc),

        .i_insert_store    (i_insert_store),
        .i_allocated_robIdx(i_allocated_robIdx),
        .o_shouldwait      (o_shouldwait),
        .o_dep_robIdx      (o_dep_robIdx),

        .i_store_issued(i_store_issued),
        .i_issue_foldpc(i_issue_foldpc),
        .i_store_robIdx(i_store_robIdx),

        .i_violation       (i_violation),
        .i_vio_store_foldpc(i_vio_store_foldpc),
        .i_vio_load_foldpc (i_vio_load_foldpc)
    );

`else
    assign o_shouldwait = 0;
`endif

endmodule

