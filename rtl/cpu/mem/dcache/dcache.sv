`include "core_define.svh"
`include "dpic.svh"


// use physic tag virtual index
// | req -> icache | select data | output
//           tlb   |
module dcache #(
    parameter int BANKS = 0,
    parameter int SETS = 32,
    parameter int WAYS = 4
)(
    input wire clk,
    input wire rst,

    // from cpu
    load2dcache_if.s if_core[2]

);

    genvar i;

    // s0:
    assign if_core.s0_gnt = if_core.s0_req;

    // s1
    reg s1_req;
    vaddr_t s1_vaddr;

    // s2
    reg s2_req;

    always_ff @( posedge clk ) begin
        int fa;
        if (rst) begin
            s1_req <= 0;
        end
        else begin
            // s1: read sram
            s1_req <= if_core.s0_req;
            s1_vaddr <= if_core.s0_vaddr;

            s2_req <= s1_req;
        end
    end

    assign if_core.s1_rdy = s1_req;
    assign if_core.s1_cft = 0;
    assign if_core.s1_miss = 0;
    assign if_core.s1_pagefault = 0;
    assign if_core.s1_illegaAddr = 0;
    assign if_core.s1_mmio = 0;
    assign if_core.s1_paddr = s1_vaddr;


    assign if_core.s2_rdy = s2_req;
    generate
        // s2: select
        for(i = 0; i < `CACHELINE_SIZE; i=i+1) begin
            always_ff @( posedge clk ) begin
                if (s1_req) begin
                    if_core_fetch.s2_data[i*8+7 : i*8] <= read_rom((s1_vaddr<<$clog2(`CACHELINE_SIZE)) + i);
                end
                else begin
                    if_core_fetch.s2_data[i*8+7 : i*8] <= 0;
                end
            end
        end
    endgenerate


endmodule


