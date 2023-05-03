




// decode -> rename -> rob



module ctrlBlock (
    input wire clk,
    input wire rst,

    // with fetch
    output wire o_decode_stall,
    input wire[`WDEF(`FETCH_WIDTH)] i_inst_vld,
    input wire[`IDEF] i_inst[`FETCH_WIDTH],
    input wire[`XDEF] i_predTakenPC[`FETCH_WIDTH]

    // with exublock

);
    genvar i,j;
    integer a,b,c,d;









    //fetch buffer
    typedef struct packed {
        logic[`IDEF] inst;
        logic[`XDEF] predTakenPC;
    } fetchEntry;
    fetchEntry fromFetch_data[`FETCH_WIDTH];
    fetchEntry toDecode_data[`DECODE_WIDTH];
    wire[`WDEF(`DECODE_WIDTH)] fetchBuffer2Decode_inst_vld;
    wire[`IDEF] fetchBuffer2Decode_insts[`DECODE_WIDTH];
    wire[`XDEF] fetchBuffer2Decode_predTakenPC[`DECODE_WIDTH];
    always_comb begin
        for (a=0;a<`FETCH_WIDTH;a=a+1) begin
            fromFetch_data[a] = '{inst:i_inst[a],predTakenPC:i_predTakenPC[a]};
        end
        for(a=0;a<`DECODE_WIDTH;a=a+1) begin
            fetchBuffer2Decode_insts[a] = toDecode_data[a].inst;
            fetchBuffer2Decode_predTakenPC[a] = toDecode_data[a].predTakenPC;
        end
    end
    fifo
    #(
        .dtype       ( fetchEntry       ),
        .INPORT_NUM  ( `FETCH_WIDTH  ),
        .OUTPORT_NUM ( `DECODE_WIDTH ),
        .DEPTH       ( 8       ),
        .USE_INIT    ( 0    )
    )
    fetch_buffer(
        .init_data   (),
        .clk         ( clk         ),
        .rst         ( rst         ),
        .i_flush     ( 0     ),

        .o_can_write ( o_can_write ),
        .i_data_wen  ( i_data_wen  ),
        .i_data_wr   ( fromFetch_data   ),

        .o_can_read  ( fetchBuffer2Decode_inst_vld  ),
        .i_data_ren  ( fetchBuffer2Decode_inst_vld  ),
        .o_data_rd   ( toDecode_data   )
    );
    //decode
    wire[`WDEF(`DECODE_WIDTH)] decode2rename_vld;
    decInfo_t decode2rename_decInfo[`DECODE_WIDTH];
    wire[`XDEF] decode2rename_predTakenPC[`DECODE_WIDTH];
    decode u_decode(
        .clk           ( clk           ),
        .rst           ( rst           ),

        .i_inst_vld    ( fetchBuffer2Decode_inst_vld    ),
        .i_inst        ( fetchBuffer2Decode_insts        ),
        .i_predTakenPC ( fetchBuffer2Decode_predTakenPC ),

        .o_decinfo_vld ( decode2rename_vld ),
        .o_decinfo     ( decode2rename_decInfo     ),
        .o_predTakenPC ( decode2rename_predTakenPC )
    );
    // rename
    rename u_rename(
        .rst           ( rst           ),
        .clk           ( clk           ),

        .i_decinfo_vld ( decode2rename_vld ),
        .i_decinfo     ( decode2rename_decInfo     ),
        .i_predTakenPC ( decode2rename_predTakenPC ),

        .o_rename_vld  ( o_rename_vld  ),
        .o_renameInfo  ( o_renameInfo  )
    );



    // dispatch








endmodule
