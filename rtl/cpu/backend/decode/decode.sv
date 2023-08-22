`include "core_define.svh"


// DESIGN:
// (1) if we found one inst is unknow:
// let inst take the except code
// check except at commit
// (2) if we found one inst need serialize:
// let inst take the serialize code
// at dispatch: wait for rob is empty
// stall pipeline, wait for rob commit signal

//TODO: finish above


// TODO:
// we may need to implement lui-load imm bypassing
// lui x1,123; ld x2,1(x1) =>  ld x2,(123<<12)+1
module decode (
    input wire clk,
    input wire rst,

    // from rename
    input wire i_stall,
    // squash
    input wire i_squash_vld,

    // from fetchBuffer
    // which inst need to deq from fetchbuffer
    output wire[`WDEF(`DECODE_WIDTH)] o_can_deq,
    input wire[`WDEF(`DECODE_WIDTH)] i_inst_vld,
    input fetchEntry_t i_inst[`DECODE_WIDTH],
    // to rename
    output reg[`WDEF(`DECODE_WIDTH)] o_decinfo_vld,
    output decInfo_t o_decinfo[`DECODE_WIDTH]
);
    genvar i;

    wire[`WDEF(`DECODE_WIDTH)] unKnown_inst;
    decInfo_t temp[`DECODE_WIDTH];
    wire[`WDEF(`DECODE_WIDTH)] temp_val;
    generate
        for(i=0;i<`DECODE_WIDTH;i=i+1) begin: gen_decode
            decoder u_decoder(
                .i_inst           ( i_inst[i].inst      ),
                .o_unkown_inst    ( unKnown_inst[i]),
                .o_decinfo        ( temp[i]     )
            );
            assign temp_val[i] = i_inst[i].has_except;
        end
    endgenerate


    reg[`WDEF(`RENAME_WIDTH)] decinfo_vld;
    decInfo_t decinfo[`DECODE_WIDTH];
    always_ff @(posedge clk) begin
        int fa;
        if (rst) begin
            decinfo_vld <= 0;
        end
        else if (!i_stall) begin
            decinfo_vld <= i_inst_vld;
            for(fa=0;fa<`DECODE_WIDTH;fa=fa+1) begin
                decinfo[fa] <= '{
                    ftq_idx     : i_inst[fa].ftq_idx,
                    ftqOffset   : i_inst[fa].ftqOffset,
                    has_except  : (unKnown_inst[fa] || temp_val[fa]),
                    except      : i_inst[fa].has_except ? i_inst[fa].except : rv_trap_t::instIllegal,
                    isRVC       : temp[fa].isRVC,
                    ismv        : temp[fa].ismv,
                    imm20       : temp[fa].imm20,
                    need_serialize : temp[fa].need_serialize,
                    rd_wen      : temp[fa].rd_wen,
                    ilrd_idx    : temp[fa].ilrd_idx,
                    ilrs_idx    : temp[fa].ilrs_idx,
                    use_imm     : temp[fa].use_imm,
                    dispQue_id  : temp[fa].dispQue_id,
                    issueQue_id : temp[fa].issueQue_id,
                    micOp_type  : temp[fa].micOp_type
                };
            end
        end
    end
    assign o_can_deq = i_stall ? 0 : i_inst_vld;

    assign o_decinfo_vld = decinfo_vld;
    assign o_decinfo = decinfo;

endmodule

