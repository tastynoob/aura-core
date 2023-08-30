`include "backend_define.svh"
`include "funcs.svh"


module age_schedule #(
    parameter int WIDTH = 16,
    parameter int OUTS = 2
)(
    input wire clk,
    input wire rst,

    input wire[`WDEF(WIDTH)] i_vld,
    input robIdx_t i_ages[WIDTH],

    output wire[`WDEF(OUTS)] o_vld,
    output wire[`WDEF($clog2(WIDTH))] o_sel_idx[OUTS]
);
    genvar i;
    /* verilator lint_off UNOPTFLAT */
    logic[`WDEF(WIDTH)] entry_selected[OUTS];
    logic[`WDEF($clog2(WIDTH))] find_idx[OUTS];


generate
    for (i=0;i<OUTS;i=i+1) begin : gen_for
        wire[`WDEF(WIDTH)] tofind_vld;
        if (i==0) begin : gen_if
            assign tofind_vld = i_vld;
        end
        else begin : gen_else
            assign tofind_vld = i_vld & (~entry_selected[i-1]);
        end
        robIdx_t rob_idx;
        logic[`WDEF($clog2(WIDTH))] sel_idx;
        logic find_vld;

        oldest_select
        #(
            .WIDTH     ( WIDTH     ),
            .dtype     ( robIdx_t  )
        )
        u_oldest_select(
        	.i_vld            ( tofind_vld ),
            .i_rob_idx        ( i_ages   ),
            .i_datas          ( i_ages   ),
            .o_oldest_rob_idx ( rob_idx  )
        );
        assign o_vld[i] = find_vld;
        assign o_sel_idx[i] = sel_idx;

        logic[`WDEF(WIDTH)] temp;
        always_comb begin
            int ca;
            if (i==0) begin
                entry_selected[i] = 0;
            end
            else begin
                entry_selected[i] = entry_selected[i-1];
            end
            sel_idx = 0;
            find_vld = 0;
            temp = 0;
            for (ca=0;ca<=WIDTH;ca=ca+1) begin
                if (tofind_vld[ca] && (i_ages[ca] == rob_idx)) begin
                    entry_selected[i][ca] = 1;
                    sel_idx = ca;
                    find_vld = 1;
                    temp[ca] = 1;
                end
            end
        end
        `ASSERT(funcs::count_one(temp) < 2);
    end
endgenerate



endmodule



