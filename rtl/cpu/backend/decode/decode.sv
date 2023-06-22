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
    // to fetch
    output wire o_stall,
    // from rename
    input wire i_stall,
    // squash
    input wire i_squash_vld,
    input squashInfo_t i_squashInfo,

    // from fetchBuffer
    // which inst need to deq from fetchbuffer
    output wire[`WDEF(`DECODE_WIDTH)] o_can_deq,
    input wire[`WDEF(`DECODE_WIDTH)] i_inst_vld,
    input wire[`IDEF] i_inst[`DECODE_WIDTH],
    input wire[`XDEF] i_inst_npc,
    // to rename
    output reg[`WDEF(`DECODE_WIDTH)] o_decinfo_vld,
    output decInfo_t o_decinfo[`DECODE_WIDTH]
);
    genvar i;
    integer a;

    wire[`WDEF(`DECODE_WIDTH)] real_inst_vld;
    `ORDER_CHECK(real_inst_vld);

    reg[`XDEF] spec_pc_base;
    wire[`XDEF] disp_pcs[`RENAME_WIDTH];

    always_comb begin
        for(a=0;a<`DECODE_WIDTH;a=a+1) begin
            // disp pc
            if (a==0) begin
                disp_pcs[a] = spec_pc_base;
            end
            else begin
                disp_pcs[a] = i_decinfo[a-1].npc;
            end
        end
    end
    always_ff @( posedge clk ) begin
        if(rst==true) begin
            spec_pc_base <= `INIT_PC;
        end
        else if (i_squash_vld) begin
            spec_pc_base <= i_squashInfo.arch_pc;
        end
        else begin
            for(a=0;a<`RENAME_WIDTH;a=a+1) begin
                if (real_inst_vld[a]) begin
                    spec_pc_base <= i_decinfo[a].npc;
                end
            end
        end
    end

    decInfo_t decinfo[`DECODE_WIDTH];
    generate
        for(i=0;i<`DECODE_WIDTH;i=i+1) begin: gen_decode
            decoder u_decoder(
                .i_inst           ( i_inst[i]      ),
                .i_inst_npc       ( disp_pcs[i]    ),
                .i_inst_npc       ( i_inst_npc[i]  ),
                .o_decinfo        ( decinfo[i]     )
            );

        end
    endgenerate

    always_comb begin
        for(a=0;a<`DECODE_WIDTH;a=a+1) begin
            if (a==0) begin
                real_inst_vld[a] = i_inst_vld[a];
            end
            else begin
                real_inst_vld[a] = i_inst_vld[a];
            end
        end

        o_can_deq = (i_stall) ? 0 : real_inst_vld;
    end

endmodule

