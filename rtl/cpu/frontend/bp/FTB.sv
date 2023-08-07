`include "frontend_define.svh"



// do predict
// s0: send req | s1: get 4 way datas | s2: output the ftbInfo
// do update or alloc
// s0: send req | s1: get 4 way datas | s2: select and update | s3: write back to ftb


package FTB_status_t;
    typedef enum logic {
        normal,
        updating
     } _;
endpackage


module FTB (
    input wire clk,
    input wire rst,
    input wire i_squash_vld,

    // do predict
    input wire i_lookup_req,
    output wire o_lookup_gnt,
    input wire[`XDEF] i_lookup_pc,
    output ftbInfo_t o_lookup_ftbInfo,
    output wire o_lookup_hit,
    output wire o_lookup_hit_rdy,

    // do update
    input wire i_update_req,
    output wire o_update_finished,
    input wire[`XDEF] i_update_pc,
    input ftbInfo_t i_update_ftbInfo
);


    FTB_status_t::_ status;

    wire[`WDEF(`FTB_WAYS)] s1_update_sel_vec;
    reg s1_update_vld;
    FTB_sram
    #(
        .SETS        ( `FTB_SETS        ),
        .WAYS        ( `FTB_WAYS        )
    )
    u_FTB_sram(
        .clk              ( clk              ),
        .rst              ( rst              ),
        .i_squash_vld     ( i_squash_vld     ),
        .i_lookup_req     ( i_lookup_req     ),
        .o_lookup_gnt     ( ),// dont care
        .i_lookup_pc      ( i_lookup_pc      ),
        .o_lookup_info    ( o_lookup_ftbInfo ),
        .o_lookup_hit     ( o_lookup_hit     ),
        .o_lookup_hit_rdy ( o_lookup_hit_rdy     ),

        .i_update_req     ( i_update_req     ),
        .i_update_pc      ( i_update_pc      ),
        .o_update_sel_vec ( s1_update_sel_vec ),

        .i_write_req      ( s1_update_vld     ),
        .i_write_way_vec  ( s1_update_sel_vec ),
        .i_write_info     ( i_update_ftbInfo  )
    );


    // global status
    always_ff @( posedge clk ) begin
        if (rst) begin
            status <= FTB_status_t::normal;
            s1_update_vld <= 0;
        end
        else begin
            if ((status == FTB_status_t::normal) && i_update_req) begin // s0
                status <= FTB_status_t::updating;
                s1_update_vld <= 1;
            end
            else if(status == FTB_status_t::updating) begin // s1
                s1_update_vld <= 0;
                status <= FTB_status_t::normal;
            end
        end
    end

    assign o_lookup_gnt = i_lookup_req && (!i_update_req) && (status == FTB_status_t::normal);
    assign o_update_finished = (status == FTB_status_t::updating);

endmodule
