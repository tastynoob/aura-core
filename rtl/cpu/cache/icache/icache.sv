`include "core_define.svh"
`include "dpic.svh"


// use physic tag virtual index
// | req -> icache | select data | output
//           tlb   |
module icache #(
    parameter int BANKS = 0,
    parameter int SETS = 32,
    parameter int WAYS = 4
)(
    input wire clk,
    input wire rst,

    // from cpu
    core2icache_if.s if_core_fetch

    // from/to next level storage
);

    genvar i;

// 3 stage icache simulate
    assign if_core_fetch.gnt = if_core_fetch.req;
    reg s1_req;
    reg s1_get2;
    reg[`BLKDEF] s1_addr;

    always_ff @( posedge clk ) begin
        int fa;
        if (rst) begin
            s1_req <= 0;
            if_core_fetch.rsp <= 0;
        end
        else begin
            // s1: read sram
            s1_req <= if_core_fetch.req;
            s1_get2 <= if_core_fetch.get2;
            s1_addr <= if_core_fetch.addr & 52'hfffffffffffff;

            if_core_fetch.rsp <= s1_req;
        end
    end

generate
    // s2: select
    for(i = 0; i < `CACHELINE_SIZE; i=i+1) begin
        always_ff @( posedge clk ) begin
            if (s1_req) begin
                if_core_fetch.line0[i*8+7 : i*8] <= read_rom((s1_addr<<$clog2(`CACHELINE_SIZE)) + i);
                if_core_fetch.line1[i*8+7 : i*8] <= read_rom(((s1_addr+1)<<$clog2(`CACHELINE_SIZE)) + i);
            end
            else begin
                if_core_fetch.line0[i*8+7 : i*8] <= 0;
                if_core_fetch.line1[i*8+7 : i*8] <= 0;
            end
        end
    end
endgenerate








endmodule


