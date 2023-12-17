`ifndef __DPIC_SVH__
`define __DPIC_SVH__

`include "base.svh"

import "DPI-C" function int check_flag(int flag);
import "DPI-C" function byte read_rom(uint64_t addr);
import "DPI-C" function void perfAccumulate(string name, uint64_t value);

// should call update_instMeta first
import "DPI-C" function void update_instMeta(uint64_t instmeta, uint64_t key, uint64_t value);
import "DPI-C" function void update_instPos(uint64_t instmeta, uint64_t pos);


package DEBUF_FLAGS;
    typedef enum int {
        ALL=0,
        FETCH
     } _;
endpackage


`define DPRINTF(flag,x) if (check_flag(flag)) $$display(x)






`endif
