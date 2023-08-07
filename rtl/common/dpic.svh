`ifndef __DPIC_SVH__
`define __DPIC_SVH__

import "DPI-C" function int check_flag(int flag);
import "DPI-C" function byte read_rom(longint addr);


package DEBUF_FLAGS;
    typedef enum int {
        ALL=0,
        FETCH
     } _;
endpackage


`define DPRINTF(flag,x) if (check_flag(flag)) $$display(x)






`endif
