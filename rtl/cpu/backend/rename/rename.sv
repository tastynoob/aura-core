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

    renameInfo_t wireInfo[`RENAME_WIDTH];
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

    generate
        for (i=0; i<`RENAME_WIDTH;i=i+1) begin
            assign wireInfo[i] = '{
                    ftq_idx     : i_decinfo[i].ftq_idx,
                    ftqOffset   : i_decinfo[i].ftqOffset,
                    has_except  : i_decinfo[i].has_except,
                    except      : i_decinfo[i].except,
                    isRVC       : i_decinfo[i].isRVC,
                    ismv        : i_decinfo[i].ismv,
                    imm20       : i_decinfo[i].imm20,
                    need_serialize : i_decinfo[i].need_serialize,
                    rd_wen      : i_decinfo[i].rd_wen,
                    ilrd_idx    : i_decinfo[i].ilrd_idx,
                    iprd_idx    : iprd_idx[i],
                    prev_iprd_idx : prev_iprd_idx[i],

                    iprs_idx    : iprs_idx[i],

                    use_imm     : i_decinfo[i].use_imm,
                    dispQue_id  : i_decinfo[i].dispQue_id,
                    issueQue_id : i_decinfo[i].issueQue_id,
                    micOp_type  : i_decinfo[i].micOp_type,
                    isStore     : i_decinfo[i].isStore,

                    instmeta    : i_decinfo[i].instmeta
                };
        end
    endgenerate

    reg[`WDEF(`RENAME_WIDTH)] rename_vld;
    renameInfo_t renameInfo[`RENAME_WIDTH];

    always_ff @( posedge clk ) begin
        int fa,fb;
        if (rst || i_squash_vld) begin
            rename_vld <= 0;
        end
        else if (!i_stall) begin
            rename_vld <= can_rename ? i_decinfo_vld : 0;
            renameInfo <= wireInfo;
            for(fa=0;fa<`RENAME_WIDTH;fa=fa+1) begin
                if (can_rename ? i_decinfo_vld[fa] : 0) begin
                    update_instPos(i_decinfo[fa].instmeta, difftest_def::AT_rename);
                    if (i_decinfo[fa].ilrd_idx != 0) begin
                        rename_alloc(i_decinfo[fa].instmeta,
                                        i_decinfo[fa].ilrd_idx,
                                        iprd_idx[fa],
                                        i_decinfo[fa].ismv);
                    end
                    if (ilrs_idx[fa][0] != 0) begin
                        rename_alloc(i_decinfo[fa].instmeta,
                                        ilrs_idx[fa][0],
                                        iprs_idx[fa][0],
                                        0);
                    end
                    if (ilrs_idx[fa][1] != 0) begin
                        rename_alloc(i_decinfo[fa].instmeta,
                                        ilrs_idx[fa][1],
                                        iprs_idx[fa][1],
                                        0);
                    end
                end
            end
        end
    end

    assign o_rename_vld = rename_vld;
    assign o_renameInfo = renameInfo;


endmodule

