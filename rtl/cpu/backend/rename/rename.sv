`include "core_define.svh"

//
module rename(
    input wire rst,
    input wire clk,
    // to decode
    output wire o_stall,
    // from dispatch
    input wire i_stall,
    // squash
    input wire i_squash_vld,
    input squashInfo_t i_squashInfo,
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
    integer a,b;

    wire can_rename;
    wire[`WDEF(`RENAME_WIDTH)] ismv;
    wire[`WDEF(`RENAME_WIDTH)] has_rd;
    ilrIdx_t ilrd_idx[`RENAME_WIDTH];
    iprIdx_t iprd_idx[`RENAME_WIDTH];
    iprIdx_t prev_iprd_idx[`RENAME_WIDTH];

    ilrIdx_t ilrs_idx[`RENAME_WIDTH][`NUMSRCS_INT];
    iprIdx_t iprs_idx[`RENAME_WIDTH][`NUMSRCS_INT];

    always_comb begin
        for(a=0;a<`RENAME_WIDTH;a=a+1) begin
            ismv[a] = (!i_stall) & i_decinfo_vld[a] & i_decinfo[a].ismv;
            has_rd[a] = (!i_stall) & i_decinfo_vld[a] & i_decinfo[a].rd_wen;
            ilrd_idx[a] = i_decinfo[a].ilrd_idx;
            for(b=0;b<`NUMSRCS_INT;b=b+1) begin
                ilrs_idx[a][b] = i_decinfo[a].ilrs_idx[b];
            end
        end
    end

    assign o_stall = (!can_rename) || i_stall;

    renametable u_renametable(
        .clk                    ( clk                    ),
        .rst                    ( rst                    ),

        .o_can_rename           ( can_rename           ),

        .i_ismv                 ( ismv                 ),
        .i_has_rd               ( has_rd               ),
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
        if ((rst==true) || i_squash_vld) begin
            rename_vld <= 0;
        end
        else if (!i_stall) begin
            rename_vld <= i_decinfo_vld;
            for(a=0;a<`RENAME_WIDTH;a=a+1) begin
                renameInfo[a] <= '{
                    ftq_idx     : i_decinfo[a].ftq_idx,
                    ftqOffset   : i_decinfo[a].ftqOffset,
                    has_except  : i_decinfo[a].has_except,
                    except      : i_decinfo[a].except,
                    isRVC       : i_decinfo[a].isRVC,
                    ismv        : i_decinfo[a].ismv,
                    imm20       : i_decinfo[a].imm20,
                    rd_wen      : i_decinfo[a].rd_wen,
                    ilrd_idx    : i_decinfo[a].ilrd_idx,
                    iprd_dix    : iprd_idx,
                    prev_iprd_idx : prev_iprd_idx,

                    iprs_idx    : iprs_idx,

                    use_imm     : i_decinfo[a].use_imm,
                    dispQue_id  : i_decinfo[a].dispQue_id,
                    dispRS_id   : i_decinfo[a].dispRS_id,
                    micOp_type  : i_decinfo[a].micOp_type
                };
            end
        end
    end

    assign o_rename_vld = rename_vld;
    assign o_renameInfo = renameInfo;


endmodule

