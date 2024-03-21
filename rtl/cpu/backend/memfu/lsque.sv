`include "backend_define.svh"



module lsque (
    load2que_if.s if_load2que[2],
    stfwd_if.s if_stfwd[2]
);
    genvar i;
    for (i=0;i<2;i=i+1) begin
        assign if_stfwd[i].s1_vaddr_match = 0;
        assign if_stfwd[i].s1_data_rdy = 0;
        assign if_stfwd[i].s2_rdy = 0;
        assign if_stfwd[i].s2_match_failed = 0;
        assign if_stfwd[i].s2_match_vec = 0;
    end
endmodule
