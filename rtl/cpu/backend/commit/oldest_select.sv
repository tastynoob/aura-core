`include "core_define.svh"


module oldest_select #(
    parameter int WIDTH = 4,
    parameter type dtype = logic[3:0]
)(
    input robIdx_t i_rob_idx[WIDTH],
    input dtype i_datas[WIDTH],
    output robIdx_t o_oldest_rob_idx,
    output dtype o_oldest_data
);
    `SET_TRACE_OFF
    localparam int left_len = WIDTH/2 + ((WIDTH%2 == 1) ? 1 : 0);
    localparam int right_len = WIDTH/2;
    `SET_TRACE_ON

    generate
        if (WIDTH==1)begin
            assign o_oldest_rob_idx = i_rob_idx[0];
            assign o_oldest_data = i_datas[0];
        end
        else if (WIDTH==2) begin
            assign o_oldest_rob_idx = (i_rob_idx[0].flipped == i_rob_idx[1].flipped) ?
            (i_rob_idx[0].idx <= i_rob_idx[1].idx ? i_rob_idx[0] : i_rob_idx[1]) :
            (i_rob_idx[0].idx > i_rob_idx[1].idx ? i_rob_idx[0] : i_rob_idx[1]);
            assign o_oldest_data = (i_rob_idx[0].flipped == i_rob_idx[1].flipped) ?
            (i_rob_idx[0].idx <= i_rob_idx[1].idx ? i_datas[0] : i_datas[1]) :
            (i_rob_idx[0].idx > i_rob_idx[1].idx ? i_datas[0] : i_datas[1]);
        end
        else begin 
            robIdx_t left,right;
            dtype left_data,right_data;
            oldest_select
            #(
                .WIDTH (left_len)
            )
            u_oldest_select_left(
                .i_rob_idx        ( i_rob_idx[0:left_len-1] ),
                .i_datas          ( i_datas[0:left_len-1]   ),
                .o_oldest_rob_idx ( left                    ),
                .o_oldest_data    ( left_data               )
            );
            oldest_select
            #(
                .WIDTH (right_len )
            )
            u_oldest_select_right(
                .i_rob_idx        ( i_rob_idx[left_len:WIDTH-1] ),
                .i_datas          ( i_datas[left_len:WIDTH-1]   ),
                .o_oldest_rob_idx ( right                       ),
                .o_oldest_data    ( right_data                  )
            );
            oldest_select
            #(
                .WIDTH (2)
            )
            u_oldest_select_0(
                .i_rob_idx        ( {left,right}            ),
                .i_datas          ( {left_data,right_data}  ),
                .o_oldest_rob_idx ( o_oldest_rob_idx        ),
                .o_oldest_data    ( o_oldest_data           )
            );
        end
    endgenerate

endmodule



