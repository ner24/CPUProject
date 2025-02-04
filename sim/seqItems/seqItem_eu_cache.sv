`ifndef ALPU_CACHE_SEQITEM_INCLUDE
`define ALPU_CACHE_SEQITEM_INCLUDE

import uvm_pkg::*;
`include "uvm_macros.svh"

class eu_cache_sequence_item #(
) extends uvm_sequence_item;

  `uvm_object_utils( eu_cache_sequence_item )

  

  constraint cons {
  }

  function new(string name = "eu_cache_sequence_item");
    super.new(name);
  endfunction

endclass

`endif //include guard
