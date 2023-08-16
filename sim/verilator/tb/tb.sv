
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
) if_ibus, if_dbus;


aura_core u_aura_core(
    .clk              (clk              ),
    .rst              (rst              ),
    .if_tilelink_bus0 (if_ibus ),
    .if_tilelink_bus1 (if_dbus )
);



endmodule



