`ifndef __FUNCS_HH__
`define __FUNCS_HH__

`include "rtl/commom/baseType.svh"

package funcs;
    function automatic int get_last_one_index(int a);
        for (int i = $bits(a); i >= 0; i = i - 1) begin
            if (a[i] == true) begin
                return i;
            end
        end
    endfunction
endpackage



`endif
