`ifndef DESIGN_PARAMETERS_DEFINE
`define DESIGN_PARAMETERS_DEFINE

//Architectural params
`define WORD_WIDTH 4
`define NUM_REG 8 //number of architectural r registers

//Execution unit params
`define EU_ENABLE_XBUF_SHORTCUTS 1
`define ALU_USE_PIPELINED_ALU 0
`define EU_CACHE_XBUF_NUM_IDX_BITS 4 //number of address bits used for the actual address of the entry
`define EU_CACHE_YBUF_NUM_IDX_BITS 4 //number of address bits used for the actual address of the entry

//Back end top level params
`define NUM_EXEC_UNITS 2

`endif
