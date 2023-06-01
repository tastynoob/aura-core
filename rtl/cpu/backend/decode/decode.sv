`include "core_define.svh"


// DESIGN:
// (1) if we found one inst is unknow:
// send message to commit, stall decode, wait for squash signal
// (2) if we found one inst need serialize:
// first: output insts that before serialized inst
// stall decode, wait for rob to be empty
// commit send to decode the signal and output the serialized inst
// wait for serialized inst is retired
// start normal execute

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
    output decInfo_t o_decinfo[`DECODE_WIDTH],
    // to commit
    output wire o_trap_vld,
    output trapInfo_t o_trapInfo
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

    reg has_trap;

    wire[`WDEF(`DECODE_WIDTH)] unknow_inst;
    wire[`IDEF] unknow_inst_code;
    wire[`XDEF] unknow_inst_pc;

    decInfo_t decinfo[`DECODE_WIDTH];
    generate
        for(i=0;i<`DECODE_WIDTH;i=i+1) begin: gen_decode
            decoder u_decoder(
                .i_inst           ( i_inst[i]      ),
                .i_inst_npc       ( disp_pcs[i]    ),
                .i_inst_npc       ( i_inst_npc[i]  ),
                .o_unknow_inst    ( unknow_inst[i] ),
                .o_decinfo        ( decinfo[i]     )
            );

        end
    endgenerate

    always_comb begin
        for(a=0;a<`DECODE_WIDTH;a=a+1) begin
            if (a==0) begin
                real_inst_vld[a] = i_inst_vld[a] & (!unknow_inst[a]);
            end
            else begin
                real_inst_vld[a] = i_inst_vld[a] & (!unknow_inst[a]) & real_inst_vld[a-1];
            end
        end
        unknow_inst_code=0;
        unknow_inst_pc=0;
        for(a=`DECODE_WIDTH-1;a>=0;a=a-1) begin
            if (i_inst_vld[a] & unknow_inst[a]) begin
                unknow_inst_code = i_inst[a];
                unknow_inst_pc = disp_pcs[a];
            end
        end

        o_can_deq = (i_stall || has_trap) ? 0 : real_inst_vld;
    end


    trapInfo_t trapInfo;

    always_ff @(posedge clk) begin
        // DESIGN: if has exception and stall, must wait for end of stall, then squash
        // if has exception and not stall, we need squash after send trap message
        if ((rst==true) || i_squash_vld || (i_stall ? false : has_trap)) begin
            o_decinfo_vld <= 0;
            trap_vld <= 0;
        end
        else if (!i_stall) begin
            o_decinfo_vld <= real_inst_vld;
            o_decinfo <= decinfo;
        end

        // only squash signal can reset the has_trap
        if ((rst==true) || i_squash_vld) begin
            has_trap <= 0;
        end
        else if(!i_stall) begin
            has_trap <= |(i_inst_vld & unknow_inst);
        end
        trapInfo <= '{
            cause   : rv_trap_t::instIllegal,
            epc     : unknow_inst_pc,
            tval    : {32'd0,unknow_inst_code}
        };
    end

    assign o_trap_vld = has_trap;
    assign o_trapInfo = trapInfo;

endmodule

