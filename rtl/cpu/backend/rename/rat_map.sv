`include "core_define.svh"


// use spec-arch rat restore
// use spec-arch rat mv elim


// mv x3,x2 : set rat_map[x3] = rat_map[x2]

module rat_map #(
    // 0:int regfile, 1: fp regfile
    parameter int COMMIT_WID = `COMMIT_WIDTH,
    parameter int WIDTH = `RENAME_WIDTH,
    parameter int NUMSRCS = `NUMSRCS_INT,
    parameter int PHYREG_TYPE = 0,
    parameter type lrIdx_t = ilrIdx_t,
    parameter type prIdx_t = iprIdx_t
)(
    input wire clk,
    input wire rst,

    // rename dest (ismv & remap_vld == 0)
    input wire[`WDEF(WIDTH)] i_ismv,
    input wire[`WDEF(WIDTH)] i_has_rd,
    input lrIdx_t i_lrd_idx[WIDTH],
    input prIdx_t i_alloc_prd_idx[WIDTH][NUMSRCS],
    output prIdx_t o_renamed_prd_idx[WIDTH],
    output prIdx_t o_prevRenamed_prd_idx[WIDTH],// used for commit release

    // rename src
    input lrIdx_t i_lrs_idx[WIDTH][NUMSRCS],
    output prIdx_t o_renamed_prs_idx[WIDTH][NUMSRCS],

    // dealloc prd
    output wire[`WDEF(COMMIT_WID)] o_dealloc_vld,
    output prIdx_t o_dealloc_prd_idx[COMMIT_WID],

    // from commit
    input wire i_squash_vld,
    input wire[`WDEF(COMMIT_WID)] i_commit_vld,
    input renameCommitInfo_t i_commitInfo[COMMIT_WID]

);
    genvar i,j;
    integer a,b;

    // if is int regfile, the x0 should be fixedmapping
    prIdx_t spec_mapping[32];
    prIdx_t arch_mapping[32];


    //read directly from rat
    prIdx_t renamed0_prs_idx[WIDTH][NUMSRCS];
    // bypass/reselect rd and rs
    prIdx_t renamed1_prs_idx[WIDTH][NUMSRCS];
    //carried by inst in rob
    prIdx_t prevRenamed_prd_idx[WIDTH];

    prIdx_t renamed_prd_idx[WIDTH];



    generate
        for(i=0;i<WIDTH;i=i+1) begin:gen_for
            for (j=0; j<NUMSRCS; j=j+1) begin:gen_for
                assign renamed0_prs_idx[i][j] = spec_mapping[i_lrs_idx[i][j]];
            end

            assign prevRenamed_prd_idx[i] = spec_mapping[i_lrd_idx[i]];
        end
    endgenerate

    always_comb begin
        for(a=0;a<WIDTH;a=a+1) begin
            // rename srcs
            for (b=0;b<NUMSRCS;b=b+1) begin
                renamed1_prs_idx[a][b] = renamed0_prs_idx[a][b];
            end
            for(integer k=0;k<a;k=k+1) begin
                for(b=0;b<NUMSRCS;b=b+1) begin
                    if ((i_lrs_idx[a][b] == i_lrd_idx[k]) && i_has_rd[k]) begin
                        renamed1_prs_idx[a][b] = renamed_prd_idx[k];
                    end
                end
            end

            // rename dest
            if ((PHYREG_TYPE==0) && i_ismv[a]) begin
                renamed_prd_idx[a] = renamed1_prs_idx[a][0];
            end else begin
                renamed_prd_idx[a] = i_alloc_prd_idx[a];
            end
        end
        if (PHYREG_TYPE==0) begin
            assert(spec_mapping[0]==0);
            assert(arch_mapping[0]==0);
        end
    end


    // update spec_mapping
    always_ff @( posedge clk ) begin
        if (rst==true) begin
            for (a=0;a<32;a=a+1) begin
                if ((PHYREG_TYPE==0) && (a==0)) begin
                    spec_mapping[a] <= 0;
                end
                else begin
                    spec_mapping[a] <= 0;
                end
            end
        end
        else if (i_squash_vld) begin
            spec_mapping <= arch_mapping;
        end
        else begin
            for (a=0;a<WIDTH;a=a+1) begin
                if (i_has_rd[a]) begin
                    assert(i_lrd_idx[a] != 0);
                    spec_mapping[i_lrd_idx[a]] <= renamed_prd_idx[a];
                end
            end
        end
    end

    // update arch_mapping
    always_ff @( posedge clk ) begin
        if (rst==true) begin
            for (a=0;a<32;a=a+1) begin
                if ((PHYREG_TYPE==0) && (a==0)) begin
                    arch_mapping[a] <= 0;
                end
                else begin
                    arch_mapping[a] <= 0;
                end
            end
        end
        else begin
            for (a=0;a<COMMIT_WID;a=a+1) begin
                if (i_commit_vld[a] && i_commitInfo[a].has_rd) begin
                    if (PHYREG_TYPE==0) begin
                        assert(i_commitInfo[a].ilrd_idx != 0);
                        arch_mapping[i_commitInfo[a].ilrd_idx] <= i_commitInfo[a].iprd_idx;
                    end
                end
            end
        end
    end


    // dealloc prd, compute which prd need to be released
    if (PHYREG_TYPE==0) begin:gen_if
        // first cycle:
        // update arch_mapping
        // compute prevRenamed_iprd
        iprIdx_t arch_prevRenamed_prd_idx[COMMIT_WID];
        always_comb begin
            // set default value
            for(a=0;a<COMMIT_WID;a=a+1) begin
                if (i_commit_vld[a] && i_commitInfo[a].has_rd) begin
                    arch_prevRenamed_prd_idx[a] = arch_mapping[i_commitInfo[a].ilrd_idx];
                end
                else begin
                    arch_prevRenamed_prd_idx[a] = 0;
                end
            end
            // bypass, compute prev_prd by spec-arch mapping
            for(a=1;a<COMMIT_WID;a=a+1) begin
                for(b=0;b<a;b=b+1) begin
                    if (i_commit_vld[a] && (i_commitInfo[a].ilrd_idx == i_commitInfo[b].i_lrd_idx)) begin
                        arch_prevRenamed_prd_idx[a] = i_commitInfo[b].iprd_idx;
                    end
                end
            end
        end

        // saved
        ilrIdx_t arch_commit_ilrd_idx_saved[COMMIT_WID];
        iprIdx_t arch_prevRenamed_prd_idx_saved[COMMIT_WID];
        always_ff @( posedge clk ) begin
            if (rst == true) begin
                arch_commit_ilrd_idx_saved <= 0;
                arch_prevRenamed_prd_idx_saved <= 0;
            end
            else begin
                // save the prevRenamed prd
                arch_prevRenamed_prd_idx_saved <= arch_prevRenamed_prd_idx;
                for (a=0;a<COMMIT_WID;a=a+1) begin
                    if (i_commit_vld[a] & i_commitInfo[a].has_rd) begin
                        arch_commit_ilrd_idx_saved[a] <= i_commitInfo[a].ilrd_idx;
                    end
                    else begin
                        arch_commit_ilrd_idx_saved[a] <= 0;
                    end
                end

            end
        end

        // second cycle: compute which prd need to be released
        wire[`WDEF(COMMIT_WID)] bits_dealloc;
        iprIdx_t real_dealloc_iprd[COMMIT_WID];

        always_comb begin
            for(a=0;a<COMMIT_WID;a=a+1) begin
                bits_dealloc[a] = true;
                for(b=0;b<COMMIT_WID;b=b+1) begin
                    if ((arch_prevRenamed_prd_idx_saved[a] == arch_mapping[arch_commit_ilrd_idx_saved[b]]) ||
                        (arch_commit_ilrd_idx_saved[b] == 0) ||
                        (arch_prevRenamed_prd_idx_saved[a] == arch_prevRenamed_prd_idx_saved[b])) begin
                        bits_dealloc[a] = false;
                    end
                end
                if (bits_dealloc[a]) begin
                    real_dealloc_iprd[a] = arch_prevRenamed_prd_idx_saved[a];
                end
                else begin
                    real_dealloc_iprd[a] = 0;
                end
            end
        end

        reg[`WDEF(COMMIT_WID)] dealloc_vld;
        iprIdx_t dealloc_iprd_idx[COMMIT_WID];

        // saved
        always_ff @( posedge clk ) begin : blockName
            if (rst==true) begin
                dealloc_vld <= 0;
            end
            else begin
                dealloc_vld <= bits_dealloc;
                dealloc_iprd_idx <= real_dealloc_iprd;
            end
        end

        assign o_dealloc_vld = dealloc_vld;
        assign o_dealloc_prd_idx = dealloc_iprd_idx;
    end
    else begin : gen_else
        // always_comb begin
        //     for(a=0;a<COMMIT_WID;a=a+1) begin
        //         o_dealloc_vld[a] = i_commit_vld[a] && i_commitInfo[a].has_rd;
        //         o_dealloc_prd_idx[a] = i_commitInfo[a].prev_iprd_idx;
        //     end
        // end
    end



    if (PHYREG_TYPE==0) begin:gen_if
        prIdx_t AAA_spec_x0 = spec_mapping[0];
        prIdx_t AAA_spec_ra = spec_mapping[1];
        prIdx_t AAA_spec_sp = spec_mapping[2];
        prIdx_t AAA_spec_gp = spec_mapping[3];
        prIdx_t AAA_spec_tp = spec_mapping[4];
        prIdx_t AAA_spec_t0 = spec_mapping[5];
        prIdx_t AAA_spec_t1 = spec_mapping[6];
        prIdx_t AAA_spec_t2 = spec_mapping[7];
        prIdx_t AAA_spec_s0 = spec_mapping[8];
        prIdx_t AAA_spec_s1 = spec_mapping[9];
        prIdx_t AAA_spec_a0 = spec_mapping[10];
        prIdx_t AAA_spec_a1 = spec_mapping[11];
        prIdx_t AAA_spec_a2 = spec_mapping[12];
        prIdx_t AAA_spec_a3 = spec_mapping[13];
        prIdx_t AAA_spec_a4 = spec_mapping[14];
        prIdx_t AAA_spec_a5 = spec_mapping[15];
        prIdx_t AAA_spec_a6 = spec_mapping[16];
        prIdx_t AAA_spec_a6 = spec_mapping[17];
        prIdx_t AAA_spec_s2 = spec_mapping[18];
        prIdx_t AAA_spec_s3 = spec_mapping[19];
        prIdx_t AAA_spec_s4 = spec_mapping[20];
        prIdx_t AAA_spec_s5 = spec_mapping[21];
        prIdx_t AAA_spec_s6 = spec_mapping[22];
        prIdx_t AAA_spec_s7 = spec_mapping[23];
        prIdx_t AAA_spec_s8 = spec_mapping[24];
        prIdx_t AAA_spec_s9 = spec_mapping[25];
        prIdx_t AAA_spec_s10 = spec_mapping[26];
        prIdx_t AAA_spec_s11 = spec_mapping[27];
        prIdx_t AAA_spec_t3 = spec_mapping[28];
        prIdx_t AAA_spec_t4 = spec_mapping[29];
        prIdx_t AAA_spec_t5 = spec_mapping[30];
        prIdx_t AAA_spec_t6 = spec_mapping[31];


        prIdx_t AAA_arch_x0 = arch_mapping[0];
        prIdx_t AAA_arch_ra = arch_mapping[1];
        prIdx_t AAA_arch_sp = arch_mapping[2];
        prIdx_t AAA_arch_gp = arch_mapping[3];
        prIdx_t AAA_arch_tp = arch_mapping[4];
        prIdx_t AAA_arch_t0 = arch_mapping[5];
        prIdx_t AAA_arch_t1 = arch_mapping[6];
        prIdx_t AAA_arch_t2 = arch_mapping[7];
        prIdx_t AAA_arch_s0 = arch_mapping[8];
        prIdx_t AAA_arch_s1 = arch_mapping[9];
        prIdx_t AAA_arch_a0 = arch_mapping[10];
        prIdx_t AAA_arch_a1 = arch_mapping[11];
        prIdx_t AAA_arch_a2 = arch_mapping[12];
        prIdx_t AAA_arch_a3 = arch_mapping[13];
        prIdx_t AAA_arch_a4 = arch_mapping[14];
        prIdx_t AAA_arch_a5 = arch_mapping[15];
        prIdx_t AAA_arch_a6 = arch_mapping[16];
        prIdx_t AAA_arch_a6 = arch_mapping[17];
        prIdx_t AAA_arch_s2 = arch_mapping[18];
        prIdx_t AAA_arch_s3 = arch_mapping[19];
        prIdx_t AAA_arch_s4 = arch_mapping[20];
        prIdx_t AAA_arch_s5 = arch_mapping[21];
        prIdx_t AAA_arch_s6 = arch_mapping[22];
        prIdx_t AAA_arch_s7 = arch_mapping[23];
        prIdx_t AAA_arch_s8 = arch_mapping[24];
        prIdx_t AAA_arch_s9 = arch_mapping[25];
        prIdx_t AAA_arch_s10 = arch_mapping[26];
        prIdx_t AAA_arch_s11 = arch_mapping[27];
        prIdx_t AAA_arch_t3 = arch_mapping[28];
        prIdx_t AAA_arch_t4 = arch_mapping[29];
        prIdx_t AAA_arch_t5 = arch_mapping[30];
        prIdx_t AAA_arch_t6 = arch_mapping[31];
    end


endmodule