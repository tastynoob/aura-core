`include "core_define.svh"




// read: s0: send req | s1: read data and select | s2: output
// write: s0: send req | s1: read data and select | s2: output and modify | s3: writeback to cache
module cache_sram #(
    parameter int BANK_TYPE = 1, // 0: none bank, 1: 2banks, 2: 4banks
    parameter int SETS = 32,
    parameter int WAYS = 4,
    parameter int ADDR_WIDTH = 64,
    parameter int CACHELINE_SIZE = 64
)(
    input wire clk,
    input wire rst,

    // lookup
    input wire i_lookup_req,
    output wire o_lookup_gnt,
    input wire[`WDEF(ADDR_WIDTH)] i_lookup_addr,
    output wire o_lookup_hit,
    output wire o_lookup_hit_rdy,
    output wire[`WDEF(WAYS)] o_lookup_sel_vec,// if not hit, sel_vec is pointed to which need replace
    output wire[`WDEF(CACHELINE_SIZE)] o_lookup_data,// if hit, send data at next cycle, if not hit, send data which need to be replaced

    // write
    input wire i_write_req,
    input wire[`WDEF(ADDR_WIDTH)] i_write_addr,// we only use index
    input wire[`WDEF(WAYS)] i_write_way_vec,
    input wire[`WDEF(CACHELINE_SIZE)] i_write_data
);
    genvar i;
    localparam int INDEX_WIDTH = $clog2(SETS);

    `ASSERT(count_one(i_write_way_vec)==1 || count_one(i_write_way_vec)==0);
    `define INDEX_RANGE INDEX_WIDTH + $clog2(CACHELINE_SIZE) + BANK_TYPE - 1 : $clog2(CACHELINE_SIZE) + BANK_TYPE
    `define TAG_RANGE ADDR_WIDTH-1 : INDEX_WIDTH + $clog2(CACHELINE_SIZE) + BANK_TYPE

    // send response
    wire sram_read_req = i_lookup_req && (!i_write_req);
    assign o_lookup_gnt = sram_read_req;
    wire[`WDEF(WAYS)] write_vec= i_write_way_vec;
    wire[`XDEF] access_addr = i_write_req ? i_write_addr : i_lookup_addr;
    wire[`WDEF(WAYS)] s1_req_hit;

    reg s1_req;
    reg s1_islookup;
    reg[`XDEF] s1_access_addr;

    wire[`WDEF(CACHELINE_SIZE)] read_data[`WDEF(WAYS)], write_data[`WDEF(WAYS)];

    sramSet
    #(
        .SETS  ( SETS  ),
        .WAYS  ( WAYS  ),
        .dtype ( logic[`WDEF(CACHELINE_SIZE)] ),
        .NEEDRESET (1)
    )
    u_sramSet(
        .clk            ( clk            ),
        .rst            ( rst            ),

        .i_addr         ( access_addr[`INDEX_RANGE]         ),
        .i_read_en      ( sram_read_req      ),
        .i_write_en_vec ( i_write_req ? i_write_way_vec : 0 ),
        .o_lookup_data    ( read_data    ),
        .i_write_data   ( write_data   )
    );

    generate
        for(i=0;i<WAYS;i=i+1) begin:gen_for
            assign write_data[i] = i_write_data;
        end
    endgenerate

    // replacement

    wire[`WDEF($clog2(SETS))] rep_setIdx = access_addr[`INDEX_RANGE];
    wire[`WDEF(WAYS)] rep_replace_vec;
    wire rep_update = (|s1_req_hit) && s1_islookup;
    wire[`WDEF(WAYS)] rep_wayhit_vec = s1_req_hit;

    random_rep
    #(
        .SETS ( SETS ),
        .WAYS ( WAYS )
    )
    u_replace_policy(
        .clk           ( clk            ),
        .rst           ( rst            ),
        .i_setIdx      ( rep_setIdx     ),
        .o_replace_vec ( rep_replace_vec ),
        .i_update_req  ( rep_update     ),
        .i_wayhit_vec  ( rep_wayhit_vec )
    );

    // hit check
    reg[`WDEF(CACHELINE_SIZE)] s2_lookup_data;
    always_ff @( posedge clk ) begin
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
                s1_islookup <= i_lookup_req && (!i_write_req);
            end

            s1_req <= sram_read_req;
            s1_access_addr <= access_addr;

            for(fa=0;fa<WAYS;fa=fa+1) begin
                if (rep_replace_vec[fa]) begin
                    s2_lookup_data <= read_data[fa];
                end
            end
            for(fa=0;fa<WAYS;fa=fa+1) begin
                if (s1_req_hit[fa]) begin
                    s2_lookup_data <= read_data[fa];
                end
            end

        end
    end

    generate
        for(i=0;i<WAYS;i=i+1) begin:gen_for
            assign s1_req_hit[i] = (read_data[i].tag == s1_access_addr[`TAG_RANGE]) && read_data[i].vld && s1_req;
        end
    endgenerate
    `ASSERT(count_one(s1_req_hit)==1 || count_one(s1_req_hit)==0);

    assign o_lookup_hit = |s1_req_hit;
    assign o_lookup_hit_rdy = s1_req && s1_islookup;
    assign o_lookup_sel_vec = |s1_req_hit ? s1_req_hit : rep_replace_vec;
    assign o_lookup_data = s2_lookup_data;

endmodule


