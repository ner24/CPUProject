`define VERIF_MODULE_SUFFIX_CONST simv
`ifdef MODE_SIMULATION
`define VERIF_MODULE_SUFFIX `VERIF_MODULE_SUFFIX_CONST
`else
`define VERIF_MODULE_SUFFIX
`endif

`define SIM_TB_MODULE(m) ``m``_`VERIF_MODULE_SUFFIX