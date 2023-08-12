
`include "core_define.svh"
`include "frontend_define.svh"

module tb (
    input wire clk,
    input wire rst
);

tilelink_if #(
    .MASTERS(2),
    .SLAVES(1),
    .ADDR_WIDTH(64),
    .DATA_WIDTH(`CACHELINE_SIZE)
) if_ibus;

aura_frontend u_aura_frontend(
    .clk          ( clk          ),
    .rst          ( rst          ),
    .if_fetch_bus ( if_ibus )
);





endmodule



