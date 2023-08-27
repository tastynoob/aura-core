`include "core_define.svh"


module bypass_sel #(
    parameter int WIDTH = 4
)(
    input wire[`WDEF(WIDTH)] i_src_vld,
    input iprIdx_t i_src_idx[WIDTH],
    input wire[`XDEF] i_src_data[WIDTH],
    input iprIdx_t i_target_idx,
    output wire o_target_vld,
    output wire[`XDEF] o_target_data
);
    always_comb begin
        int j,temp;
        temp=0;
        o_target_vld = 0;
        o_target_data = 0;
        for(j=0;j<WIDTH;j=j+1) begin
            if (i_src_vld[j] && (i_src_idx[j] == i_target_idx)) begin
                temp = temp + 1;
                o_target_data = i_src_data[j];
                o_target_vld = true;
            end
        end
        assert(temp < 2);
    end

endmodule





