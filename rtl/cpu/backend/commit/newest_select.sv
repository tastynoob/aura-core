`include "core_define.svh"


module newest_select #(
    parameter int  WIDTH = 4,
    parameter type dtype = logic [3:0]
) (
    input wire [`WDEF(WIDTH)] i_vld,
    input robIdx_t i_rob_idx[WIDTH],
    input dtype i_datas[WIDTH],
    output robIdx_t o_newest_rob_idx,
    output dtype o_newest_data
);
    localparam int left_len = WIDTH / 2 + ((WIDTH % 2 == 1) ? 1 : 0);
    localparam int right_len = WIDTH / 2;

    generate
        if (WIDTH == 1) begin
            assign o_newest_rob_idx = i_rob_idx[0];
            assign o_newest_data = i_datas[0];
        end
        else if (WIDTH == 2) begin
            assign o_newest_rob_idx =
            (&i_vld) ?
            (`OLDER_THAN(i_rob_idx[1], i_rob_idx[0]) ? i_rob_idx[0] : i_rob_idx[1])
            :
            (i_vld[0] ? i_rob_idx[0] : i_rob_idx[1]);

            assign o_newest_data =
            (&i_vld) ?
            (`OLDER_THAN(i_rob_idx[1], i_rob_idx[0]) ? i_datas[0] : i_datas[1])
            :
            (i_vld[0] ? i_datas[0] : i_datas[1]);
        end
        else begin : gen_select
            robIdx_t left, right;
            dtype left_data, right_data;
            newest_select #(
                .WIDTH(left_len),
                .dtype(dtype)
            ) u_newest_select_left (
                .i_vld           (i_vld[left_len-1 : 0]),
                .i_rob_idx       (i_rob_idx[0:left_len-1]),
                .i_datas         (i_datas[0:left_len-1]),
                .o_newest_rob_idx(left),
                .o_newest_data   (left_data)
            );
            newest_select #(
                .WIDTH(right_len),
                .dtype(dtype)
            ) u_newest_select_right (
                .i_vld           (i_vld[WIDTH-1 : left_len]),
                .i_rob_idx       (i_rob_idx[left_len:WIDTH-1]),
                .i_datas         (i_datas[left_len:WIDTH-1]),
                .o_newest_rob_idx(right),
                .o_newest_data   (right_data)
            );
            newest_select #(
                .WIDTH(2),
                .dtype(dtype)
            ) u_newest_select_0 (
                .i_vld           ({|i_vld[WIDTH-1 : left_len], |i_vld[left_len-1 : 0]}),
                .i_rob_idx       ({left, right}),
                .i_datas         ({left_data, right_data}),
                .o_newest_rob_idx(o_newest_rob_idx),
                .o_newest_data   (o_newest_data)
            );
        end
    endgenerate

endmodule



