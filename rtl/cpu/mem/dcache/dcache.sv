`include "core_define.svh"
`include "dpic.svh"


// use physic tag virtual index
// | req -> icache | select data | output
//           tlb   |
module dcache #(
    parameter int BANKS = 0,
    parameter int SETS  = 32,
    parameter int WAYS  = 4
) (
    input wire clk,
    input wire rst,

    // from cpu
    load2dcache_if.s if_core[2],
    sta2mmu_if.s if_sta[2]
);
    genvar i, j;

    generate
        for (i = 0; i < 2; i = i + 1) begin : gen_load
            // s0:
            assign if_core[i].s0_gnt = 1;
            // s1
            reg s1_req;
            logic [`XDEF] s1_vaddr;
            logic [`XDEF] s1_paddr;
            // s2
            reg s2_req;
            always_ff @(posedge clk) begin
                int fa;
                if (rst) begin
                    s1_req <= 0;
                end
                else begin
                    // s1: read tlb
                    s1_req <= if_core[i].s0_req;
                    s1_paddr <= (if_core[i].s0_vaddr >> $clog2(`CACHELINE_SIZE));
                    s1_vaddr <= if_core[i].s0_vaddr;

                    s2_req <= if_core[i].s1_req;
                end
            end
            // s1: read data sram
            assign if_core[i].s1_rdy = s1_req;
            assign if_core[i].s1_cft = 0;
            assign if_core[i].s1_miss = 0;
            assign if_core[i].s1_pagefault = 0;
            assign if_core[i].s1_illegaAddr = 0;
            assign if_core[i].s1_mmio = 0;
            assign if_core[i].s1_paddr = s1_vaddr;

            // s2: output
            assign if_core[i].s2_rdy = s2_req;
            for (j = 0; j < `CACHELINE_SIZE; j = j + 1) begin
                always_ff @(posedge clk) begin
                    if (if_core[i].s1_req) begin
                        if_core[i].s2_data[j*8+7 : j*8] <= read_rom((s1_paddr << $clog2(`CACHELINE_SIZE)) + j);
                    end
                    else begin
                        if_core[i].s2_data[j*8+7 : j*8] <= 0;
                    end
                end
            end
        end

        for (i = 0; i < 2; i = i + 1) begin : gen_store
            reg s1_req;
            logic[`XDEF] s1_paddr;

            always_ff @( posedge clk ) begin
                if (rst) begin
                    s1_req <= 0;
                end
                else begin
                    s1_req <= if_sta[i].s0_req;
                    s1_paddr <= if_sta[i].s0_vaddr;
                end
            end

            assign if_sta[i].s1_miss = 0;
            assign if_sta[i].s1_pagefault = 0;
            assign if_sta[i].s1_illegaAddr = 0;
            assign if_sta[i].s1_mmio = 0;
            assign if_sta[i].s1_paddr = s1_paddr;

        end
    endgenerate

endmodule


