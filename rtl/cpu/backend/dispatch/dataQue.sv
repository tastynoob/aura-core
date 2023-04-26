


`define DATAQUE_TYPE_IMM 0
`define DATAQUE_TYPE_PC 1



// used for imm buffer, pc buffer, predTakenpc buffer
module dataQue #(
    parameter int DEPTH = 30,
    parameter int INPORT_NUM = 4,
    parameter int OUTPORT_NUM = 4,
    parameter int QUE_TYPE = 0
)(
    input wire clk,
    input wire rst
);







endmodule



