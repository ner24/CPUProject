`ifndef EU_SEQITEM_INCLUDE
`define EU_SEQITEM_INCLUDE
import uvm_pkg::*;
`include "uvm_macros.svh"

import pkg_dtypes::*;
class execution_unit_sequence_item extends uvm_sequence_item;

  `uvm_object_utils(execution_unit_sequence_item)

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
  rand  type_iqueue_entry    dispatched_instr_i;
  rand  logic                dispatched_instr_valid_i;
        logic                ready_for_next_instr_o;

  /*`define INC_CONSTRAINTS
  `include "simTests/execution_unit/tests.svh"
  `undef INC_CONSTRAINTS*/

  function new(string name = "execution_unit_sequence_item");
    super.new(name);
  endfunction

endclass

`endif
