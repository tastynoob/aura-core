`include "core_define.svh"




// use physic tag virtual index
// req -> icache | select data | output
//         tlb   |
module icache #(
    parameter int BANKS = 0,
    parameter int SETS = 32,
    parameter int WAYS = 4
)(
    input wire clk,
    input wire rst,

    // from cpu
    core2icache_if.s core_access_if

    // from/to next level storage
);




endmodule


