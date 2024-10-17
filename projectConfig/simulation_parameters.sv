`define VERIF_MODULE_SUFFIX_CONST simv
`ifdef MODE_SIMULATION
`define VERIF_MODULE_SUFFIX simv
`else
`define VERIF_MODULE_SUFFIX
`endif
