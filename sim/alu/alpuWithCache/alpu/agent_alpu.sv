`ifndef ALPU_AGENT_INCLUDE
`define ALPU_AGENT_INCLUDE

import uvm_pkg::*;
`include "uvm_macros.svh"

`include "seqItem_alpu.sv"

//leaving custom class even though not strictly necessary but might be useful
class alpu_sequencer #(
  parameter REG_WIDTH = 4
) extends uvm_sequencer #(alpu_sequence_item #( .REG_WIDTH(REG_WIDTH)) );

  `uvm_component_param_utils(alpu_sequencer#( .REG_WIDTH(REG_WIDTH) ))

  // Tasks and Functions
  function new(string name = "alpu_sequencer", uvm_component parent = null);
    super.new(name, parent);
  endfunction
endclass

class alpu_driver #(
  parameter REG_WIDTH = 4
) extends uvm_driver #(alpu_sequence_item #( .REG_WIDTH(REG_WIDTH) ));

  `uvm_component_param_utils(alpu_driver#( .REG_WIDTH(REG_WIDTH) ))

  virtual intf_alpu #(
    .REG_WIDTH(REG_WIDTH)
  ) vintf;
  
  function new(string name = "test_design_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    `uvm_info(get_full_name(), "Building...", UVM_LOW)
    super.build_phase(phase);
    if(!uvm_config_db#( virtual intf_alpu #(.REG_WIDTH(REG_WIDTH)) )::get(null, "*", "intf_alpu_top", vintf)) begin
      `uvm_fatal(get_type_name(), "Could not find specified alu interface. Check interface in uvm config")
    end
  endfunction
  
  virtual task reset_phase(uvm_phase phase);
    @(posedge vintf.clk);
    vintf.reset_n <= 1'b1;
  endtask

  virtual task run_phase(uvm_phase phase);
    forever begin
      @(posedge vintf.clk);
      seq_item_port.get_next_item(req);
      drive(req);
      seq_item_port.item_done();
    end
  endtask

  virtual task drive(alpu_sequence_item #( .REG_WIDTH(REG_WIDTH) ) seq_item);
    vintf.a_i     <= seq_item.a;
    vintf.b_i     <= seq_item.b;
    vintf.instr_i <= seq_item.instr;
    vintf.cin_i   <= '0;
  endtask
endclass

class alpu_agent #(
  parameter REG_WIDTH = 4
) extends uvm_agent;

  `uvm_component_param_utils(alpu_agent#( .REG_WIDTH(REG_WIDTH) ))

  alpu_driver #(
    .REG_WIDTH(REG_WIDTH)
  ) driver;
  
  alpu_sequencer #(
    .REG_WIDTH(REG_WIDTH)
  ) sequencer;

  function new(string name = "alpu_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    `uvm_info(get_full_name(), "Building...", UVM_LOW)

    driver    = alpu_driver    #( .REG_WIDTH(REG_WIDTH) ) ::type_id::create("driver", this);
    sequencer = alpu_sequencer #( .REG_WIDTH(REG_WIDTH) ) ::type_id::create("sequencer", this);
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    `uvm_info(get_full_name(), "Connecting...", UVM_LOW)
    driver.seq_item_port.connect(sequencer.seq_item_export);
  endfunction
endclass

`endif //include guard
