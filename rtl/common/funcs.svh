`ifndef __FUNCS_SVH__
`define __FUNCS_SVH__

`include "base.svh"

package funcs;

    function automatic int get_last_one_index(logic [31:0] a);
        for (int i = 31; i >= 0; i = i - 1) begin
            if (a[i]) begin
                return i + 1;
            end
        end
        return 0;
    endfunction

    function automatic int continuous_one(logic [31:0] a);
        int c = 0;
        for (int i = 0; i < 32; i = i + 1) begin
            if (a[i] == 0) begin
                return i;
            end
        end
        return 32;
    endfunction

    function automatic int count_one(logic [31:0] a);
        int c = 0;
        for (int i = 0; i < 32; i = i + 1) begin
            if (a[i]) begin
                c = c + 1;
            end
        end
        return c;
    endfunction


endpackage



`endif
