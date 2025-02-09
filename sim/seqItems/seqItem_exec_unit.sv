`ifndef EU_SEQITEM_INCLUDE
`define EU_SEQITEM_INCLUDE
import uvm_pkg::*;
`include "uvm_macros.svh"

`include "design_parameters.sv"

import pkg_dtypes::*;
class execution_unit_sequence_item extends uvm_sequence_item;

  `uvm_object_utils(execution_unit_sequence_item)

  localparam NUM_PARALLEL_INSTR_DISPATCHES = `NUM_PARALLEL_INSTR_DISPATCHES;
  localparam LOG2_NUM_EXEC_UNITS = `LOG2_NUM_EXEC_UNITS;

  logic               reset_n;

  //interconnect
  rand  type_icon_tx_channel icon_rx0_i;
        type_icon_rx_channel icon_rx0_resp_o;
  rand  type_icon_tx_channel icon_rx1_i;
        type_icon_rx_channel icon_rx1_resp_o;
  
  //not using type_icon_tx_channel for tx because ports
  //go in different directions
        type_exec_unit_data  icon_tx_data_o;
  rand  type_exec_unit_addr  icon_tx_addr_i;
  rand  logic                icon_tx_req_valid_i;
        logic                icon_tx_success_o;

  //iqueue
  rand  type_iqueue_entry    dispatched_instr_i [NUM_PARALLEL_INSTR_DISPATCHES-1:0];
  rand  logic                dispatched_instr_valid_i [NUM_PARALLEL_INSTR_DISPATCHES-1:0];
  rand  logic [LOG2_NUM_EXEC_UNITS-1:0] dispatched_instr_alloc_euidx_i [NUM_PARALLEL_INSTR_DISPATCHES-1:0];
        logic                ready_for_next_instrs_o;

  /*`define INC_CONSTRAINTS
  `include "simTests/execution_unit/tests.svh"
  `undef INC_CONSTRAINTS*/

  function new(string name = "execution_unit_sequence_item");
    super.new(name);
  endfunction

endclass

`endif
