`define VERIF_MODULE_SUFFIX_CONST _simv
`ifdef MODE_SIMULATION
`define MODE_SIM 1
`define VERIF_MODULE_SUFFIX `VERIF_MODULE_SUFFIX_CONST
`else
`define MODE_SIM 0
`define VERIF_MODULE_SUFFIX
`endif

`define SIM_TB_MODULE(m) ``m```VERIF_MODULE_SUFFIX

//additional sim only defines

//renamed assembly output from emulated front end
//this should be set a cmd line
`ifndef BACKEND_ASSEMBLY_TXT_PATH_WITHOUT_QUOTES
`define BACKEND_ASSEMBLY_TXT_PATH_WITHOUT_QUOTES
`endif
`define QUOTE_WRAP(w) `"w`"
`define BACKEND_ASSEMBLY_TXT_PATH `QUOTE_WRAP(`BACKEND_ASSEMBLY_TXT_PATH_WITHOUT_QUOTES)
