`ifndef ALU_TB_SEQUENCE_ITEM_INCLUDE
`define ALU_TB_SEQUENCE_ITEM_INCLUDE

import uvm_pkg::*;
`include "uvm_macros.svh"

class alu_tb_sequence_item #(
  parameter REG_WIDTH = 4
) extends uvm_sequence_item;

  `uvm_object_param_utils(alu_tb_sequence_item#( .REG_WIDTH(REG_WIDTH) ))

  rand  logic [REG_WIDTH-1:0] a;
  rand  logic [REG_WIDTH-1:0] b;
        logic           [3:0] instr;
        logic   [REG_WIDTH:0] out; //1 longer than reg width to include cout

  constraint operandRange {
    a inside{[0:100]};
    b inside{[0:100]};
    //instr inside {4'd4};
  }

  function new(string name = "alu_tb_sequence_item");
    super.new(name);
  endfunction

endclass

`endif //include guard
