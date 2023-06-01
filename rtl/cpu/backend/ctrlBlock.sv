
`include "core_define.svh"



// decode -> rename -> rob



module ctrlBlock (
    input wire clk,
    input wire rst,

    // with fetch
    output wire o_decode_stall,
    input wire[`WDEF(`FETCH_WIDTH)] i_inst_vld,
    input fetchEntry_t i_inst[`FETCH_WIDTH]

    // with exublock

);
    genvar i,j;
    integer a,b,c,d;




/******************** fetch buffer ********************/
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
        .dtype       ( fetchEntry_t       ),
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
/******************** decode ********************/
    wire[`WDEF(`DECODE_WIDTH)] decode2rename_vld;
    decInfo_t decode2rename_decInfo[`DECODE_WIDTH];
    wire[`XDEF] decode2rename_predTakenPC[`DECODE_WIDTH];


    decode u_decode(
        .clk           (clk           ),
        .rst           (rst           ),

        .o_stall       (o_stall       ),
        .i_stall       (i_stall       ),
        .i_squash_vld  (i_squash_vld  ),
        .i_squashInfo  (i_squashInfo  ),

        .o_can_deq     (o_can_deq     ),
        .i_inst_vld    (i_inst_vld    ),
        .i_inst        (i_inst        ),
        .i_inst_npc    (i_inst_npc    ),

        .o_decinfo_vld (o_decinfo_vld ),
        .o_decinfo     (o_decinfo     ),

        .o_trap_vld    (o_trap_vld    ),
        .o_trapInfo    (o_trapInfo    )
    );




/******************** rename ********************/


    rename u_rename(
        .rst           (rst           ),
        .clk           (clk           ),

        .o_stall       (o_stall       ),
        .i_stall       (i_stall       ),

        .i_squash_vld  (i_squash_vld  ),
        .i_squashInfo  (i_squashInfo  ),

        .i_commit_vld  (i_commit_vld  ),
        .i_commitInfo  (i_commitInfo  ),
        .i_decinfo_vld (i_decinfo_vld ),
        .i_decinfo     (i_decinfo     ),
        .o_rename_vld  (o_rename_vld  ),
        .o_renameInfo  (o_renameInfo  )
    );



    // dispatch






endmodule
