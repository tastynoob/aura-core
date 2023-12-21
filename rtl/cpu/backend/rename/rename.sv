`include "backend_define.svh"


import "DPI-C" function void rename_alloc(uint64_t seq, uint64_t logic_idx, uint64_t physcial_idx, uint64_t ismv);


module rename(
    input wire rst,
    input wire clk,
    // to decode
    output wire o_stall,
    // from dispatch
    input wire i_stall,
    // squash
    input wire i_squash_vld,
    // from commit
    input wire[`WDEF(`COMMIT_WIDTH)] i_commit_vld,
    input renameCommitInfo_t i_commitInfo[`COMMIT_WIDTH],
    // from decode
    input wire[`WDEF(`DECODE_WIDTH)] i_decinfo_vld,
    input decInfo_t i_decinfo[`DECODE_WIDTH],
    // to dispatch
    output wire[`WDEF(`RENAME_WIDTH)] o_rename_vld,
    output renameInfo_t o_renameInfo[`RENAME_WIDTH]
);
    genvar i;

    wire can_rename;
    wire[`WDEF(`RENAME_WIDTH)] ismv;
    wire[`WDEF(`RENAME_WIDTH)] has_rd;
    ilrIdx_t ilrd_idx[`RENAME_WIDTH];
    iprIdx_t iprd_idx[`RENAME_WIDTH];
    iprIdx_t prev_iprd_idx[`RENAME_WIDTH];

    ilrIdx_t ilrs_idx[`RENAME_WIDTH][`NUMSRCS_INT];
    iprIdx_t iprs_idx[`RENAME_WIDTH][`NUMSRCS_INT];

    generate
        for(i=0;i<`RENAME_WIDTH;i=i+1) begin:gen_for
            assign ismv[i] = i_decinfo_vld[i] & i_decinfo[i].ismv;
            assign has_rd[i] = i_decinfo_vld[i] & i_decinfo[i].rd_wen & (!i_stall);
            assign ilrd_idx[i] = i_decinfo[i].ilrd_idx;
        end
    endgenerate

    always_comb begin
        int ca,cb;
        for(ca=0;ca<`RENAME_WIDTH;ca=ca+1) begin
            for(cb=0;cb<`NUMSRCS_INT;cb=cb+1) begin
                ilrs_idx[ca][cb] = i_decinfo[ca].ilrs_idx[cb];
            end
        end
    end

    assign o_stall = (!can_rename) || i_stall;

    renametable u_renametable(
        .clk                    ( clk                    ),
        .rst                    ( rst                    ),

        .o_can_rename           ( can_rename           ),

        .i_ismv                 ( ismv                 ),
        .i_has_rd               ( has_rd ),
        .i_ilrd_idx             ( ilrd_idx             ),
        .o_renamed_iprd_idx     ( iprd_idx     ),
        .o_prevRenamed_iprd_idx ( prev_iprd_idx ),

        .i_ilrs_idx             ( ilrs_idx             ),
        .o_renamed_iprs_idx     ( iprs_idx     ),

        .i_squash_vld           ( i_squash_vld           ),
        .i_commit_vld           ( i_commit_vld           ),
        .i_commitInfo           ( i_commitInfo           )
    );

    reg[`WDEF(`RENAME_WIDTH)] rename_vld;
    renameInfo_t renameInfo[`RENAME_WIDTH];

    always_ff @( posedge clk ) begin
        int fa,fb;
        if ((rst==true) || i_squash_vld) begin
            rename_vld <= 0;
        end
        else if (!i_stall) begin
            rename_vld <= can_rename ? i_decinfo_vld : 0;
            for(fa=0;fa<`RENAME_WIDTH;fa=fa+1) begin
                renameInfo[fa] <= '{
                    ftq_idx     : i_decinfo[fa].ftq_idx,
                    ftqOffset   : i_decinfo[fa].ftqOffset,
                    has_except  : i_decinfo[fa].has_except,
                    except      : i_decinfo[fa].except,
                    isRVC       : i_decinfo[fa].isRVC,
                    ismv        : i_decinfo[fa].ismv,
                    imm20       : i_decinfo[fa].imm20,
                    need_serialize : i_decinfo[fa].need_serialize,
                    rd_wen      : i_decinfo[fa].rd_wen,
                    ilrd_idx    : i_decinfo[fa].ilrd_idx,
                    iprd_idx    : iprd_idx[fa],
                    prev_iprd_idx : prev_iprd_idx[fa],

                    iprs_idx    : iprs_idx[fa],

                    use_imm     : i_decinfo[fa].use_imm,
                    dispQue_id  : i_decinfo[fa].dispQue_id,
                    issueQue_id : i_decinfo[fa].issueQue_id,
                    micOp_type  : i_decinfo[fa].micOp_type,
                    isStore     : i_decinfo[fa].isStore,

                    instmeta    : i_decinfo[fa].instmeta
                };

                if (can_rename ? i_decinfo_vld[fa] : 0) begin
                    update_instPos(i_decinfo[fa].instmeta, difftest_def::AT_rename);
                    if (i_decinfo[fa].ilrd_idx != 0) begin
                        rename_alloc(i_decinfo[fa].instmeta,
                                        i_decinfo[fa].ilrd_idx,
                                        iprd_idx[fa],
                                        i_decinfo[fa].ismv);
                    end
                end
            end
        end
    end

    assign o_rename_vld = rename_vld;
    assign o_renameInfo = renameInfo;


endmodule

