`include "base.svh"

// DESIGN:
// it only store the tags and datas
// the meta data need need external connection
module dataSet #(
    parameter int ADDR_WIDTH = 64,
    parameter int SETS = 32,
    parameter int WAYS = 4,
    parameter type dtype = logic[`WDEF(64*8)],
    // 0:rand 1:plru
    parameter int REPLACE_POLICY = 0
)(
    input wire clk,
    input wire rst,

    // read meta sram and compare
    input wire i_rd_req,
    input wire[`WDEF(ADDR_WIDTH)] i_rd_tag,
    output wire o_rd_hit,
    // return message
    output wire o_rd_finished,
    output dtype o_rd_data,

    // write data (use set_idx and way_idx)
    input wire i_wr_vld,
    input wire[`WDEF($clog2(SETS))] i_wr_set_idx,
    input wire[`WDEF($clog2(WAYS))] i_wr_way_idx,
    input dtype i_write_data
);
    int offset_wid = $clog2($bits(dtype)/8);
    int index_wid =  $clog2(SETS);
    int tag_wid = ADDR_WIDTH - offset_wid - index_wid;
    int cache_tagSram_size = tag_wid * SETS * WAYS;
    int cache_dataSram_size = $bits(dtype) * SETS * WAYS;
    int cache_all_size = cache_tagSram_size + cache_dataSram_size;






endmodule
