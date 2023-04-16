`include "base.svh"





module bypass_sel #(
    parameter int DEPTH = 4,
    parameter int IDXWIDTH = $clog2(128),
    parameter type dtype = logic
)(
    input wire[`WDEF(DEPTH)] i_src_vld,
    input wire[`WDEF(IDXWIDTH)] i_src_idx[DEPTH],
    input dtype i_src_data[DEPTH],
    input wire[`WDEF(IDXWIDTH)] i_target_idx,
    output dtype o_target_data
);
    always_comb begin
        integer j,temp;
        temp=0;
        o_target_data = 0;
        for(j=0;j<DEPTH;j=j+1) begin
            if (i_src_vld[j] && i_src_idx[j] == i_target_idx) begin
                temp = temp + 1;
                o_target_data = i_src_data[j];
            end
        end
        assert(temp < 2);
    end

endmodule





