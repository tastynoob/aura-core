`include "frontend_define.svh"
`include "funcs.svh"
import funcs::*;

typedef struct packed {
    logic [`WDEF(`FTB_TAG_WIDTH)] tag;
    logic vld;
    ftbInfo_t info;
} ftbEntry_t;

module FTB_sram #(
    parameter int SETS = 32,
    parameter int WAYS = 4
) (
    input wire clk,
    input wire rst,
    input wire i_squash_vld,

    // lookup
    input wire i_lookup_req,
    output wire o_lookup_gnt,  // s0
    input wire [`XDEF] i_lookup_pc,
    output wire o_lookup_hit,  // s1
    output wire o_lookup_hit_rdy,  // s1
    output ftbInfo_t o_lookup_info,  // s2

    // update
    input wire i_update_req,  // s0: lookup for update, s1: write for update
    input wire [`XDEF] i_update_pc,
    output wire [`WDEF(WAYS)] o_update_sel_vec,  // the wayIdx needed update which was select

    // write
    input wire i_write_req,
    input wire [`WDEF(WAYS)] i_write_way_vec,
    input ftbInfo_t i_write_info
);
    genvar i;
    localparam int INDEX_WIDTH = $clog2(SETS);  // 5

    `define INDEX_RANGE INDEX_WIDTH+1 - 1 : 1
    `define TAG_RANGE `FTB_TAG_WIDTH + (INDEX_WIDTH+1)-1 : INDEX_WIDTH+1

    // send response
    wire sram_read_req = i_lookup_req || i_update_req;
    assign o_lookup_gnt = sram_read_req;
    wire [`WDEF(WAYS)] write_vec = i_write_way_vec;
    wire [`XDEF] access_addr = i_update_req ? i_update_pc : i_lookup_pc;
    wire [`WDEF(WAYS)] s1_req_hit;

    reg s1_req;
    reg s1_islookup;
    reg [`XDEF] s1_access_addr;
    wire [`WDEF(`FTB_TAG_WIDTH)] s1_tag = s1_access_addr[`TAG_RANGE];

    ftbEntry_t read_data[WAYS], write_data[WAYS];

    wire [`WDEF(INDEX_WIDTH)] index = access_addr[`INDEX_RANGE];
    sramSet #(
        .SETS     (SETS),
        .WAYS     (WAYS),
        .dtype    (ftbEntry_t),
        .NEEDRESET(1)
    ) u_sramSet (
        .clk(clk),
        .rst(rst),

        .i_addr        (index),
        .i_read_en     (sram_read_req),
        .i_write_en_vec(i_write_req ? i_write_way_vec : 0),
        .o_read_data   (read_data),
        .i_write_data  (write_data)
    );
    generate
        for (i = 0; i < WAYS; i = i + 1) begin
            assign write_data[i] = '{tag: s1_access_addr[`TAG_RANGE], vld: 1, info: i_write_info};
        end
    endgenerate

    // replacement

    wire [`WDEF($clog2(SETS))] rep_setIdx = access_addr[`INDEX_RANGE];
    wire [`WDEF(WAYS)] rep_replace_vec;
    wire rep_update = (|s1_req_hit) && s1_islookup;
    wire [`WDEF(WAYS)] rep_wayhit_vec = s1_req_hit;

    random_rep #(
        .SETS(SETS),
        .WAYS(WAYS)
    ) u_random_rep (
        .clk          (clk),
        .rst          (rst),
        .i_setIdx     (rep_setIdx),
        .o_replace_vec(rep_replace_vec),
        .i_update_req (rep_update),
        .i_wayhit_vec (rep_wayhit_vec)
    );

    // hit check
    ftbInfo_t s2_lookup_info;
    always_ff @(posedge clk) begin
        int fa;
        if (rst) begin
            s1_req <= 0;
            s1_islookup <= 1;
        end
        else begin
            if (i_squash_vld) begin
                s1_islookup <= 0;
            end
            else begin
                s1_islookup <= i_lookup_req && (!i_update_req);
            end

            s1_req <= sram_read_req;
            s1_access_addr <= access_addr;

            for (fa = 0; fa < WAYS; fa = fa + 1) begin
                if (s1_req_hit[fa]) begin
                    s2_lookup_info <= read_data[fa].info;
                end
            end
        end
    end

    generate
        for (i = 0; i < WAYS; i = i + 1) begin
            assign s1_req_hit[i] = (read_data[i].tag == s1_access_addr[`TAG_RANGE]) && read_data[i].vld && s1_req;
        end
    endgenerate
    `ASSERT(count_one(s1_req_hit) == 1 || count_one(s1_req_hit) == 0);

    assign o_lookup_info = s2_lookup_info;
    assign o_lookup_hit = |s1_req_hit;
    assign o_lookup_hit_rdy = s1_req && s1_islookup;

    assign o_update_sel_vec = |s1_req_hit ? s1_req_hit : rep_replace_vec;

endmodule


