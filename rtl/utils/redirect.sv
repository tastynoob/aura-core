`include "base.svh"


//input_vld : 1001
//input : dcba
//output : bxxa

//ordered in
//unordered out
module redirect #(
    parameter type dtype = logic,
    parameter int  NUM   = 4
) (
    input wire [`WDEF(NUM)] i_arch_vld,
    input dtype i_arch_datas[NUM],
    output dtype o_redirect_datas[NUM]
);
    wire[`SDEF(NUM)] sel_offset[NUM];

    generate
        genvar i;
        //todo: finish it
        for(i=0;i<NUM;i=i+1)begin:gen_for
            if (i==0) begin:gen_if
                assign sel_offset[0] = 0;
            end
            else begin:gen_else
            count_one
            #(
                .WIDTH ( i+1 )
            )
            u_count_one(
                .i_a   ( i_arch_vld[i-1:0]),
                .o_sum ( sel_offset[i] )
            );
            end

            always_comb begin
                if(i_arch_vld[i])begin
                    o_redirect_datas[i] = i_arch_datas[sel_offset[i]];
                end else begin
                    o_redirect_datas[i] = 0;
                end
            end
        end
    endgenerate
endmodule
