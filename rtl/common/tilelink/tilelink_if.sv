`include "tilelink.svh"


interface tilelink_if #(
    parameter int MASTERS = 2,
    parameter int SLAVES = 2,
    parameter int ADDR_WIDTH = 32,// bit
    parameter int DATA_WIDTH = 32// Byte
);
    // A channel
    logic[`WDEF(3)] a_code;
    logic[`WDEF(3)] a_param;
    logic[`WDEF($clog2(DATA_WIDTH))] a_size;
    logic[`WDEF($clog2(MASTERS))] a_source;
    logic[`WDEF(ADDR_WIDTH)] a_address;
    logic[`WDEF(DATA_WIDTH)] a_mask;
    logic[`WDEF(DATA_WIDTH*8)] a_data;
    logic a_corrupt;
    logic a_valid;
    logic a_ready;

    // D channel
    logic[`WDEF(3)] d_opcode;
    logic[`WDEF(2)] d_param;
    logic[`WDEF($clog2(DATA_WIDTH))] d_size;
    logic[`WDEF($clog2(MASTERS))] d_source;
    logic[`WDEF($clog2(SLAVES))] d_sink;
    logic d_denied;
    logic[`WDEF(DATA_WIDTH*8)] d_data;
    logic d_corrupt;
    logic d_valid;
    logic d_ready;


    modport m (
        output a_code,
        output a_param,
        output a_size,
        output a_source,
        output a_address,
        output a_mask,
        output a_data,
        output a_corrupt,
        output a_valid,
        input a_ready,

        input d_opcode,
        input d_param,
        input d_size,
        input d_source,
        input d_sink,
        input d_denied,
        input d_data,
        input d_corrupt,
        input d_valid,
        output d_ready
    );

    modport s (
        input a_code,
        input a_param,
        input a_size,
        input a_source,
        input a_address,
        input a_mask,
        input a_data,
        input a_corrupt,
        input a_valid,
        output a_ready,

        output d_opcode,
        output d_param,
        output d_size,
        output d_source,
        output d_sink,
        output d_denied,
        output d_data,
        output d_corrupt,
        output d_valid,
        input d_ready
    );

    function int Ahandshake();
        Ahandshake = a_valid && a_ready;
    endfunction;

    function int Dhandshake();
        Dhandshake = d_valid && d_ready;
    endfunction;

endinterface








