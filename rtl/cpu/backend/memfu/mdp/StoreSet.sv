`include "backend_define.svh"




//FIXME: strict

// decode -> rename -> dispatch
//        -> SSIT -> LFST
// NOTE: storeset pipeline is corresponds to rename and dispatch pipeline
module StoreSet #(
    parameter int SSIT_SIZE = 1024,
    parameter int LFST_SIZE = 32
) (
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
    input wire [`WDEF(`MEMDEP_FOLDPC_WIDTH)] i_vio_load_foldpc
);
    typedef logic [`WDEF($clog2(LFST_SIZE))] ssid_t;

    reg [`WDEF(32)] reset_count;
    wire set_clear;
    assign set_clear = reset_count >= 25000;

    reg [`WDEF(SSIT_SIZE)] ssit_vld;
    ssid_t ssit[SSIT_SIZE];

    reg [`WDEF(LFST_SIZE)] lfst_vld;
    robIdx_t lfst[LFST_SIZE];

    reg [`WDEF(`RENAME_WIDTH)] s1_found_vld;
    ssid_t s1_found_ssid[`RENAME_WIDTH];

    // store issued
    reg [`WDEF(`STORE_ISSUE_WIDTH)] issue_ssid_found;
    ssid_t issue_ssid[`STORE_ISSUE_WIDTH];
    robIdx_t issue_robIdx[`STORE_ISSUE_WIDTH];

    //NOTE: for now we just use lowest bits of foldpc as store set id
    // ssid = foldpc & ((1<<LFSTSIZE) -1)
    ssid_t s1_vio_store_ssid, s1_vio_load_ssid;
    reg violation;
    reg s1_vio_store_found, s1_vio_load_found;
    reg [`WDEF(`MEMDEP_FOLDPC_WIDTH)] s1_vio_store_index, s1_vio_load_index;

    wire [`WDEF(2)] vio_mode;
    assign vio_mode = {s1_vio_store_found, s1_vio_load_found};

    always_ff @(posedge clk) begin
        int fa;
        if (rst) begin
            reset_count <= 0;
        end
        else begin
            if (set_clear) begin
                reset_count <= 0;
            end
            else begin
                reset_count <= reset_count + 1;
            end
        end

        if (rst || set_clear) begin
            ssit_vld <= 0;
            lfst_vld <= 0;

            s1_found_vld <= 0;

            issue_ssid_found <= 0;
        end
        else begin
            if (!i_stall) begin
                // s1: lookup
                for (fa = 0; fa < `RENAME_WIDTH; fa = fa + 1) begin
                    if (ssit_vld[i_foldpc[fa]]) begin
                        s1_found_ssid[fa] <= ssit[i_foldpc[fa]];
                        s1_found_vld[fa] <= 1;
                    end
                    else begin
                        s1_found_vld[fa] <= 0;
                    end
                end

                // s2: insert store
                for (fa = 0; fa < `RENAME_WIDTH; fa = fa + 1) begin
                    if (s1_found_vld[fa] && i_insert_store[fa]) begin
                        lfst_vld[s1_found_ssid[fa]] <= 1;
                        lfst[s1_found_ssid[fa]] <= i_allocated_robIdx[fa];
                    end
                end

            end

            // store issued
            for (fa = 0; fa < `STORE_ISSUE_WIDTH; fa = fa + 1) begin
                if (ssit_vld[i_issue_foldpc[fa]]) begin
                    issue_ssid_found[fa] <= 1;
                    issue_ssid[fa] <= ssit[i_issue_foldpc[fa]];
                end
                else begin
                    issue_ssid_found[fa] <= 0;
                end
                issue_robIdx[fa] <= i_store_robIdx[fa];
                // reset
                if (issue_ssid_found[fa] && lfst_vld[issue_ssid[fa]] && lfst[issue_ssid[fa]] == issue_robIdx[fa]) begin
                    lfst_vld[issue_ssid[fa]] <= 0;
                end
            end


            // violation update
            // TODO:
            // s1: lookup ssit
            assert (i_violation ? (!violation) : 1);
            if (i_violation) begin
                violation <= 1;
                if (ssit_vld[i_vio_store_foldpc]) begin
                    s1_vio_store_found <= 1;
                    s1_vio_store_ssid <= ssit[i_vio_store_foldpc];
                end
                else begin
                    s1_vio_store_ssid <= i_vio_store_foldpc;
                end
                if (ssit_vld[i_vio_load_foldpc]) begin
                    s1_vio_load_found <= 1;
                    s1_vio_load_ssid <= ssit[i_vio_load_foldpc];
                end
                else begin
                    s1_vio_load_ssid <= i_vio_load_foldpc;
                end
                s1_vio_store_index <= i_vio_store_foldpc;
                s1_vio_load_index <= i_vio_load_foldpc;
            end
            else begin
                violation <= 0;
            end
            // s2: update ssit table
            if (violation) begin
                if (vio_mode == 2'b00) begin
                    ssit_vld[s1_vio_store_index] <= 1;
                    ssit[s1_vio_store_index] <= s1_vio_store_ssid;
                    ssit_vld[s1_vio_load_index] <= 1;
                    ssit[s1_vio_load_index] <= s1_vio_load_ssid;
                end
                else if (vio_mode == 2'b01) begin  // vio load found
                    ssit_vld[s1_vio_store_index] <= 1;
                    ssit[s1_vio_store_index] <= s1_vio_store_ssid;
                end
                else if (vio_mode == 2'b10) begin  // vio store found
                    ssit_vld[s1_vio_load_index] <= 1;
                    ssit[s1_vio_load_index] <= s1_vio_load_ssid;
                end
                else if (vio_mode == 2'b11) begin
                    if (s1_vio_store_ssid > s1_vio_load_ssid) begin
                        ssit[s1_vio_store_index] <= s1_vio_load_ssid;
                    end
                    else begin
                        ssit[s1_vio_load_index] <= s1_vio_store_ssid;
                    end
                end
            end
        end
    end



    // rename->dispatch found memDep_producer
    logic [`WDEF(`RENAME_WIDTH)] shouldwait;
    robIdx_t dep_producer[`RENAME_WIDTH];
    always_comb begin
        int ca, cb;
        shouldwait = 0;
        for (ca = 0; ca < `RENAME_WIDTH; ca = ca + 1) begin
            dep_producer[ca] = 0;
            if (s1_found_vld[ca] && lfst_vld[s1_found_ssid[ca]]) begin
                // producer's robIdx
                shouldwait[ca] = 1;
                dep_producer[ca] = lfst[s1_found_ssid[ca]];
            end
            // bypass
            for (cb = 0; cb < ca; cb = cb + 1) begin
                if (s1_found_vld[ca] &&
                s1_found_vld[cb] && i_insert_store[cb] && (s1_found_ssid[ca] == s1_found_ssid[cb])) begin
                    shouldwait[ca] = 1;
                    dep_producer[ca] = i_allocated_robIdx[cb];
                end
            end
        end
    end
    assign o_shouldwait = shouldwait;
    assign o_dep_robIdx = dep_producer;


endmodule



