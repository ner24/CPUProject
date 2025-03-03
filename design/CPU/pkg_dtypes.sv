`ifndef INCLUDE_EXEC_UNIT_DTYPES
`define INCLUDE_EXEC_UNIT_DTYPES

`include "design_parameters.sv"

package pkg_dtypes;

  localparam REN_ADDR_SPEC_IDX_NUM_BITS = `REN_ADDR_SPEC_IDX_NUM_BITS;
  localparam REN_ADDR_UID_NUM_BITS = `REN_ADDR_UID_NUM_BITS;
  localparam LOG2_NUM_EXEC_UNITS = `LOG2_NUM_EXEC_UNITS;
  localparam DATA_WIDTH = `WORD_WIDTH;
  localparam LOG2_NUM_INSTRUCTIONS_PER_EXEC_TYPE = `LOG2_NUM_INSTRUCTIONS_PER_EXEC_TYPE;

  // ------------------------------------------
  // Exec unit data and address formats
  // ------------------------------------------

  typedef struct packed {
    logic [DATA_WIDTH-1:0]    data;
  } type_exec_unit_data;

  typedef struct packed { //TODO: update when implementing front end
    logic [LOG2_NUM_EXEC_UNITS-1:0]        euidx;
    logic [REN_ADDR_UID_NUM_BITS-1:0]      uid;
    logic [REN_ADDR_SPEC_IDX_NUM_BITS-1:0] spec; //specific address (within specified uid)
  } type_exec_unit_addr;

  typedef struct packed {
    logic [REN_ADDR_UID_NUM_BITS-1:0]  uid;
    logic [REN_ADDR_SPEC_IDX_NUM_BITS-1:0]    spec;
  } type_alu_local_addr;

  // ------------------------------------------
  // Interconnect formats
  // ------------------------------------------

  /*typedef struct packed {
    logic [LOG2_NUM_ALPU-1:0] eu_idx;
    logic  [LOG2_NUM_REG-1:0] reg_idx;
  } type_icon_addr;*/

  typedef struct packed {
    //logic                  addr_opx;
    type_exec_unit_addr    addr;
    type_exec_unit_data    data;
    logic                  valid;
  } type_icon_tx_channel;
  //typedef type_icon_tx_channel type_icon_channel;

  typedef struct packed {
    logic                  success;
  } type_icon_rx_channel;

  typedef struct packed {
    logic                  req_valid;
    type_exec_unit_data    data_tx;
    logic                  data_valid_tx;
    type_exec_unit_addr    src_addr;
  } type_icon_tx_channel_chside;

  typedef struct packed {
    type_exec_unit_data    data_rx;
    logic                  data_valid_rx;
    logic                  success;
  } type_icon_rx_channel_chside;

  localparam TOT_NUM_ICON_INTERFACES = (2**LOG2_NUM_EXEC_UNITS) * 2;
  typedef struct packed {
    //execution unit receivers (op0 and op1)
    logic [TOT_NUM_ICON_INTERFACES-1:0] eus;
    //extra receivers (str buffer, mx reg bank)
    logic receiver_str;
    logic receiver_mxreg;
  } type_icon_receivers_list;

  //*2 for op0 and op1 in each eu
  typedef struct packed {
    type_exec_unit_addr      src_addr;

    type_exec_unit_data      data;
    logic                    data_valid;

    type_icon_receivers_list receiver_list;
    type_icon_receivers_list success_list;
  } type_icon_channel;

  typedef struct packed {
    type_exec_unit_addr      src_addr;
    type_icon_receivers_list receiver_list;
  } type_icon_instr;

  // ------------------------------------------
  // ALU interface
  // ------------------------------------------

  typedef struct packed {
    type_exec_unit_data    op0_data;
    logic                  op0_valid;

    type_exec_unit_data    op1_data;
    logic                  op1_valid;

    //pass opd addr through alu to better implement alu pipelines which take more than 0 cycles
    type_exec_unit_addr    opd_addr;

    //ready to write to address opd (which means cache index has_been_read is high)
    //note that this is on the cache interface that sits at the end of the alu pipeline
    //the other attributes in this struct are at the alu input interface
    logic                  opd_store_success;
  } type_alu_channel_rx; //rx on alu side

  typedef struct packed {
    type_exec_unit_data      opd_data;
    type_exec_unit_addr      opd_addr;

    //can be low if no instruction is being processed
    logic                    opd_valid;
  } type_alu_channel_tx; //tx on alu side

  // -----------------------------------
  // Instruction format
  // -----------------------------------

  //operand format
  //Note that decreasing the value of this param will increase area efficiency
  localparam IQUEUE_IMM_PADDING = $bits(type_exec_unit_addr) - $bits(type_exec_unit_data);
  //localparam logic[31:0] IQUEUE_IMM_PADDING = ADDR_IMM_WIDTH_DIFF[31] ? ADDR_IMM_WIDTH_DIFF : 0 - ADDR_IMM_WIDTH_DIFF;
  typedef struct packed {
    logic [IQUEUE_IMM_PADDING-1:0] zero;
    type_exec_unit_data      data;
  } type_iqueue_immediate;

  typedef union packed {
    type_exec_unit_addr      as_addr;
    type_iqueue_immediate    as_imm;
  } union_iqueue_operand;

  typedef enum logic {
    IMM_OR_NONE,
    REG
  } enum_instr_operand_type;

  //opcode format
  typedef enum logic[1:0] {
    EXEC_UNIT, //instructions dispatched to exec units that do not update cmp flags
    EXEC_UNIT_CMP, //instructions dispatched to exec units that update cmp flags
    LDR_STR, //load/store
    BRANCH //branch instruction
  } enum_instr_execution_type;

  typedef struct packed {
    enum_instr_execution_type exec_type;
    logic [LOG2_NUM_INSTRUCTIONS_PER_EXEC_TYPE-1:0] specific_instr;
  } type_iqueue_opcode;

  //structure of whole instruction
  typedef struct packed {
    type_iqueue_opcode opcode;
    
    //logic                    opxSwap; //if = 1, op0 should be found in rx1 and op1 in rx0
    union_iqueue_operand     op0;
    enum_instr_operand_type  op0m;
    union_iqueue_operand     op1;
    enum_instr_operand_type  op1m;
                               //NOTE: opxm assignments are based on path lengths. This gives shorter ones
    type_exec_unit_addr  opd;
    //logic                opd_stry;
    //logic                opd_strx;
  } type_iqueue_entry;

  // ----------------------------------------
  // Instruction set
  // ----------------------------------------
  // note that the datatypes for all opcode types
  // must be equal

  typedef enum logic [LOG2_NUM_INSTRUCTIONS_PER_EXEC_TYPE:0] {
    MVN,
    AND,
    ORR,
    XOR,
    ADD,
    SUB,
    NAND,
    NOR,
    XNOR,
    LSR,
    LSL//,
    //RRO,
    //LRO
  } enum_instr_exec_unit;

  typedef enum logic [LOG2_NUM_INSTRUCTIONS_PER_EXEC_TYPE:0] {
    CMP //not adding any other instructions for now
  } enum_instr_exec_unit_cmp;

  typedef enum logic [LOG2_NUM_INSTRUCTIONS_PER_EXEC_TYPE:0] {
    LDR,
    STR
  } enum_instr_ldr_str;

  typedef enum logic [LOG2_NUM_INSTRUCTIONS_PER_EXEC_TYPE:0] {
    B,    //unconditional branch
    B_GT, //branch when greater than
    B_LT, //branch when less than
    B_EQ, //branch when equal
    B_Z,  //branch on zero
    B_NZ, //branch on non zero
    B_MI, //branch on negative
    B_PL, //branch on positive
    B_OV  //branch on overflow
  } enum_instr_branch;

endpackage

`endif //include guard
