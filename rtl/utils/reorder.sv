`include "base.svh"



//reorder the data and output
//0101 -> 0011
//1001 -> 0011

//unordered in
//ordered out
module reorder #(
    parameter type dtype = logic,
    parameter int NUM = 4
) (
    input wire[`WDEF(NUM)] i_data_vld,
    input dtype i_datas[NUM],
    output wire[`WDEF(NUM)] o_data_vld,
    output dtype o_reorder_datas[NUM]
);
    wire[`SDEF(NUM)] count_vld;
    wire[`SDEF(NUM)] sel_offset[NUM];
    count_one
    #(
        .WIDTH ( NUM )
    )
    u_count_one(
        .i_a   ( i_data_vld ),
        .o_sum ( count_vld  )
    );
    assign o_data_vld = count_vld == 0 ? 0 : ((1<<count_vld) - 1);
    generate
        genvar i,j;
        for(i=0;i<NUM;i=i+1) begin:gen_0
                count_one
                #(
                    .WIDTH ( i+1 )
                )
                u_count_one(
                    .i_a   ( i_data_vld[i:0] ),
                    .o_sum ( sel_offset[i] )
                );
                always_comb begin
                    o_reorder_datas[i] = i_datas[i];
                    if(i_data_vld[i])begin
                        o_reorder_datas[sel_offset[i]-1] = i_datas[i];
                    end
                end
        end
    endgenerate


endmodule
