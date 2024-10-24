`ifndef ALPU_CACHE_SEQITEM_INCLUDE
`define ALPU_CACHE_SEQITEM_INCLUDE

import uvm_pkg::*;
`include "uvm_macros.svh"

class alpu_cache_sequence_item #(
  parameter ADDR_WIDTH = 4,
  parameter DATA_WIDTH = 4
) extends uvm_sequence_item;

  `uvm_object_param_utils(alpu_cache_sequence_item#( .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH) ))

  rand logic  [ADDR_WIDTH-1:0] addr_i;
  rand logic  [DATA_WIDTH-1:0] wdata_i;

  logic                   ce_i;
  logic                   we_i;

  logic  [DATA_WIDTH-1:0] rdata_o;
  logic                   rvalid_o;
  logic                   wack_o;

  constraint cons {
  }

  function new(string name = "alpu_cache_sequence_item");
    super.new(name);
  endfunction

endclass

`endif //include guard
