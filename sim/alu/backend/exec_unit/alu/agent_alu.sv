import uvm_pkg::*;
`include "uvm_macros.svh"

`include "seqItem_alu.sv"

class alu_sequencer extends uvm_sequencer #(alu_sequence_item);
  `uvm_component_utils(alu_sequencer)

  function new(string name = "alu_sequencer", uvm_component parent = null);
    super.new(name, parent);
  endfunction
endclass

class alu_driver extends uvm_driver #(alu_sequence_item);

  `uvm_component_utils(alu_driver)

  virtual intf_alu vintf;
  
  function new(string name = "test_design_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    `uvm_info(get_full_name(), "Building...", UVM_LOW)
    super.build_phase(phase);
    if(!uvm_config_db#( virtual intf_alu )::get(this, "", "intf_alu_top", vintf)) begin
      `uvm_fatal(get_type_name(), "Could not find specified alu interface. Check interface in uvm config")
    end
  endfunction
  
  virtual task reset_phase(uvm_phase phase);
    vintf.reset_n = 1'b0;
    @(posedge vintf.clk);
    vintf.reset_n = 1'b1;
  endtask

  virtual task run_phase(uvm_phase phase);
    forever begin
      @(posedge vintf.clk);
      seq_item_port.get_next_item(req);
      drive(req);
      seq_item_port.item_done();
    end
  endtask

  virtual task drive(alu_sequence_item seq_item);
    vintf.alu_rx_i            <= seq_item.alu_rx_i;
    vintf.curr_instr_i        <= seq_item.curr_instr_i;
    vintf.curr_instr_valid_i  <= seq_item.curr_instr_valid_i;
  endtask

endclass

class alu_agent extends uvm_agent;

  `uvm_component_utils(alu_agent)

  alu_driver driver;
  alu_sequencer sequencer;

  function new(string name = "alu_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    `uvm_info(get_full_name(), "Building...", UVM_LOW)

    driver = alu_driver::type_id::create("driver", this);
    sequencer = alu_sequencer::type_id::create("sequencer", this);
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    `uvm_info(get_full_name(), "Connecting...", UVM_LOW)
    driver.seq_item_port.connect(sequencer.seq_item_export);
  endfunction
endclass
