`include "base.svh"

// write data to Dcache
// we need to copy data and wait for write-finished signal
// then we can release this data


// link storeQue to Dcache
module StoreBuffer #(
    parameter int SIZE = 16,
    parameter int DATAWIDTH = 32*8//32Byte
)(
    input wire clk,
    input wire rst
);












endmodule
