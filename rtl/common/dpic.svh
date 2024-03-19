`ifndef __DPIC_SVH__
`define __DPIC_SVH__

`include "base.svh"

import "DPI-C" function byte read_rom(uint64_t addr);

// should call update_instMeta first
import "DPI-C" function void update_instMeta(
    uint64_t instmeta,
    uint64_t key,
    uint64_t value
);
import "DPI-C" function void update_instPos(
    uint64_t instmeta,
    uint64_t pos
);
import "DPI-C" function void goto_fu(
    uint64_t instmeta,
    uint64_t fu_id
);







`endif
