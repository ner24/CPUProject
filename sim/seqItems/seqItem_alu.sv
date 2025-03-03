`ifndef ALPU_SEQITEM_INCLUDE
`define ALPU_SEQITEM_INCLUDE
import uvm_pkg::*;
`include "uvm_macros.svh"

import pkg_dtypes::*;
class alu_sequence_item extends uvm_sequence_item;

  `uvm_object_param_utils(alu_sequence_item)

  logic               reset_n;

  type_exec_unit_data op0_data_from_driver;
  type_exec_unit_data op1_data_from_driver;
  rand type_alu_channel_rx alu_rx_i;
  type_alu_channel_tx alu_tx_o;

  type_iqueue_opcode      opcode_from_driver;
  rand type_iqueue_entry  curr_instr_i;
  rand logic              curr_instr_valid_i;

  logic               ready_for_next_instr_o;

  constraint cons {
    curr_instr_valid_i == 1'b1;
    curr_instr_i.opcode == opcode_from_driver;
    curr_instr_i.op0.as_imm.zero == 'b0;
    curr_instr_i.op1.as_imm.zero == 'b0;
    alu_rx_i.op0_valid == 1'b1;
    alu_rx_i.op1_valid == 1'b1;
    alu_rx_i.op0_data == op0_data_from_driver;
    alu_rx_i.op1_data == op1_data_from_driver;
    alu_rx_i.opd_store_success == 1'b1;
  }


  function new(string name = "alpu_sequence_item");
    super.new(name);
  endfunction

endclass

`endif //include guard
