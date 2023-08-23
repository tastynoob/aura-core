`include "core_define.svh"




//TODO: how about MEMartix implement?
//TODO: how about spec-arch mv elim ( we can use the traditional rename and save space )

module renametable(
    input wire clk,
    input wire rst,

    output wire o_can_rename,

    // int rename dest
    input wire[`WDEF(`RENAME_WIDTH)] i_ismv,
    input wire[`WDEF(`RENAME_WIDTH)] i_has_rd,
    input ilrIdx_t i_ilrd_idx[`RENAME_WIDTH],
    output iprIdx_t o_renamed_iprd_idx[`RENAME_WIDTH],
    output iprIdx_t o_prevRenamed_iprd_idx[`RENAME_WIDTH],

    // int rename srcs
    input ilrIdx_t i_ilrs_idx[`RENAME_WIDTH][`NUMSRCS_INT],
    output iprIdx_t o_renamed_iprs_idx[`RENAME_WIDTH][`NUMSRCS_INT],

    // from commit
    input wire i_squash_vld,
    input wire[`WDEF(`COMMIT_WIDTH)] i_commit_vld,
    input renameCommitInfo_t i_commitInfo[`WDEF(`COMMIT_WIDTH)],

    output iprIdx_t o_specRenameMapping[32]
);
    genvar i;

    wire[`WDEF(`COMMIT_WIDTH)] int_dealloc_vld;
    iprIdx_t int_dealloc_iprd_idx[`COMMIT_WIDTH];
    iprIdx_t int_alloc_iprd_idx[`COMMIT_WIDTH];
    rat_map
    #(
        .COMMIT_WID  ( `COMMIT_WIDTH  ),
        .WIDTH       ( `RENAME_WIDTH       ),
        .NUMSRCS     ( `NUMSRCS_INT     ),
        .PHYREG_TYPE ( 0 ),
        .lrIdx_t     ( ilrIdx_t     ),
        .prIdx_t     ( iprIdx_t     )
    )
    u_rat_map(
        .clk                   ( clk                   ),
        .rst                   ( rst                   ),

        .i_ismv                ( o_can_rename ? i_ismv : 0   ),
        .i_has_rd              ( o_can_rename ? i_has_rd : 0 ),
        .i_lrd_idx             ( i_ilrd_idx                  ),
        .i_alloc_prd_idx       ( int_alloc_iprd_idx        ),
        .o_renamed_prd_idx     ( o_renamed_iprd_idx     ),
        .o_prevRenamed_prd_idx ( o_prevRenamed_iprd_idx ),

        .i_lrs_idx             ( i_ilrs_idx             ),
        .o_renamed_prs_idx     ( o_renamed_iprs_idx     ),

        .o_dealloc_vld         ( int_dealloc_vld         ),
        .o_dealloc_prd_idx     ( int_dealloc_iprd_idx     ),

        .i_squash_vld          ( i_squash_vld          ),
        .i_commit_vld          ( i_commit_vld          ),
        .i_commitInfo          ( i_commitInfo          ),

        .o_specRenameMapping (o_specRenameMapping)
    );

    wire[`WDEF(`COMMIT_WIDTH)] commit_has_rd, commit_ismv;
    freelist u_freelist(
        .clk             ( clk             ),
        .rst             ( rst             ),

        .o_can_alloc     ( o_can_rename     ),
        .i_alloc_req     ( (i_has_rd & (~i_ismv))     ),
        .o_alloc_prIdx   ( int_alloc_iprd_idx   ),

        .i_dealloc_req   ( int_dealloc_vld   ),
        .i_dealloc_prIdx ( int_dealloc_iprd_idx ),

        .i_resteer_vld   ( i_squash_vld   ),
        // this commit vld = i_commit_vld & commitInfo.has_rd & (~commitInfo.ismv)
        // it muse be update in one cycle with commit
        .i_commit_vld    ( (i_commit_vld & commit_has_rd & (~commit_ismv))    )
    );

    generate
        for(i=0;i<`COMMIT_WIDTH;i=i+1) begin:gen_for
            assign commit_has_rd[i] = i_commitInfo[i].has_rd;
            assign commit_ismv[i] = i_commitInfo[i].ismv;
        end
    endgenerate

endmodule
