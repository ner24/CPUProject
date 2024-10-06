import uvm_pkg::*;
`include "uvm_macros.svh"
`include "alu_tb_sequence_item.sv"

//leaving custom class even though not strictly necessary but might be useful
class alu_tb_sequencer #(
  parameter REG_WIDTH = 4
) extends uvm_sequencer #(alu_tb_sequence_item #( .REG_WIDTH(REG_WIDTH)) );

  `uvm_component_param_utils(alu_tb_sequencer#( .REG_WIDTH(REG_WIDTH) ))

  // Tasks and Functions
  function new(string name = "alu_tb_sequencer", uvm_component parent = null);
    super.new(name, parent);
  endfunction
endclass
