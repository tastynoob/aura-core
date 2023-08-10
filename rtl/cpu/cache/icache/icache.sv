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

// 3 stage icache simulate
    assign if_core_fetch.gnt = if_core_fetch.req;
    reg s1_req;
    reg s1_get2;
    reg[`BLKDEF] s1_addr;

    reg s2_req;
    reg s2_get2;
    reg[`BLKDEF] s2_addr;

    always_ff @( posedge clk ) begin
        int fa;
        if (rst) begin
            if_core_fetch0.rsp <= 0;
            if_core_fetch1.rsp <= 0;
        end
        else begin
            // s1
            if (if_core_fetch.req) begin
                s1_req <= if_core_fetch.req;
                s1_get2 <= if_core_fetch.get2;
                s1_addr <= if_core_fetch.addr;
            end
            // s2
            s2_req <= s1_req;
            s2_get2 <= s1_get2;
            s2_addr <= s1_addr;
            // s3
            for(fa=0;fa<`CACHELINE_SIZE;fa=fa+1) begin
                if_core_fetch.line0[fa*8+7:fa*8] <= read_rom((s2_addr<<$clog2(`CACHELINE_SIZE)) + fa);
                if_core_fetch.line0[fa*8+7:fa*8] <= read_rom(((s2_addr+1)<<$clog2(`CACHELINE_SIZE)) + fa);
            end
            if_core_fetch.rsp <= s2_req;
        end
    end







endmodule


