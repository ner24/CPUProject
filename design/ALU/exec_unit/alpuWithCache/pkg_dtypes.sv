`ifndef INCLUDE_EXEC_UNIT_DTYPES
`define INCLUDE_EXEC_UNIT_DTYPES

`include "alu_parameters.sv"

//yes, not actually a package
package exec_unit_dtypes;

  localparam LOG2_NUM_ALPU = $clog2(`NUM_EXEC_UNITS);
  localparam LOG2_NUM_REG = $clog2(`NUM_REG);
  localparam DATA_WIDTH = `ALU_REG_WIDTH;

  typedef struct packed {
    logic                     is_output; //i.e. not intermediate and to send back to main reg file. Should be MSB
    logic [LOG2_NUM_ALPU-1:0] eu_idx;
    logic  [LOG2_NUM_REG-1:0] reg_idx;
  } type_exec_unit_addr;

  typedef struct packed {
    logic [LOG2_NUM_ALPU-1:0] eu_idx;
    logic  [LOG2_NUM_REG-1:0] reg_idx;
  } type_icon_addr;

  typedef struct packed {
    type_icon_addr         addr;
    logic [DATA_WIDTH-1:0] data;
    logic                  valid;
  } type_icon_channel;

  typedef struct packed {
    logic                  ready;
  } type_icon_rx_channel;

  typedef struct packed {
    logic [DATA_WIDTH-1:0] op0_data;
    logic                  op0_valid;

    logic [DATA_WIDTH-1:0] op1_data;
    logic                  op1_valid;

    logic                  opd_ready; //ready to write to address opd (which means cache index has_been_read is high)
  } type_alpu_channel_rx; //rx on alpu side

  typedef struct packed {
    logic [DATA_WIDTH-1:0]   opd_data;
    type_exec_unit_addr      opd_addr;
    logic                    opd_opx; //op0 if 0, op1 if 1. Used to assign to appropriate x buffer for foreign writes
    logic                    opd_valid; //can be low if no instruction is being processed
  } type_alpu_channel_tx; //tx on alpu side

  //TODO: the addr and immediate lengths are significantly different
  //which causes area inefficiencies (especially when using immediates which are smaller of the two)
  //How to fix?
  localparam IQUEUE_IMM_PADDING = $bits(type_exec_unit_addr) - DATA_WIDTH;
  typedef struct packed {
    logic [IQUEUE_IMM_PADDING-1:0] p;
    logic [DATA_WIDTH-1:0] data;
  } type_iqueue_immediate;

  typedef union packed {
    type_exec_unit_addr      as_addr;
    type_iqueue_immediate   as_immediate;
  } union_iqueue_operand;

  typedef struct packed {
    //logic [?-1:0] operation; //WIP
    union_iqueue_operand     op0;
    logic                    op0m; //m for mode: 1 for address, 0 for immediate

    union_iqueue_operand op1;
    logic                op1m; //1 for address, 0 for immediate
                               //NOTE: opxm assignments are based on path lengths. This gives shorter ones
    type_exec_unit_addr  opd;
  } type_iqueue_entry;

  typedef struct packed {
    logic [DATA_WIDTH-1:0] data;
    logic                  has_been_read;
  } type_xcache_data;

  typedef struct packed {
    logic [DATA_WIDTH-1:0] data;
    logic                  has_been_read;
  } type_ycache_data;

endpackage

`endif //include guard
