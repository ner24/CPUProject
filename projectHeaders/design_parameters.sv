`ifndef DESIGN_PARAMETERS_DEFINE
`define DESIGN_PARAMETERS_DEFINE

// --------------------------------
// Architectural/general params
// --------------------------------
`define WORD_WIDTH 8
`define NUM_REG 8 //number of architectural r registers
`define LOG2_NUM_INSTRUCTIONS_PER_EXEC_TYPE 4

// --------------------------------
// Renamed address config
// --------------------------------
`define REN_ADDR_SPEC_IDX_NUM_BITS 3
`define REN_ADDR_UID_NUM_BITS 4

// --------------------------------
// Execution unit params
// --------------------------------
`define EU_ENABLE_XBUF_SHORTCUTS 1
`define ALU_USE_PIPELINED_ALU 0
`define EU_CACHE_XBUF_NUM_IDX_BITS 4 //number of address bits used for the actual address of the entry
`define EU_CACHE_YBUF_NUM_IDX_BITS 4 //number of address bits used for the actual address of the entry
`define EU_LOG2_IQUEUE_LENGTH 3

// --------------------------------
// Back end top level params
// --------------------------------
`define LOG2_NUM_EXEC_UNITS 2
`define LOG2_NUM_ICON_CHANNELS 2

`endif
