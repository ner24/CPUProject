import uvm_pkg::*;
`include "uvm_macros.svh"

`include "alu_tb_driver.sv"
`include "alu_tb_sequencer.sv"
`include "alu_tb_monitor.sv"

class alu_tb_agent #(
  parameter REG_WIDTH = 4
) extends uvm_agent;

  `uvm_component_param_utils(alu_tb_agent#( .REG_WIDTH(REG_WIDTH) ))

  //alu_tb_agent_cfg agnt_cfg;

  alu_tb_driver #(
    .REG_WIDTH(REG_WIDTH)
  ) driver;
  
  alu_tb_sequencer #(
    .REG_WIDTH(REG_WIDTH)
  ) sequencer;

  alu_tb_monitor #(
    .REG_WIDTH(REG_WIDTH)
  ) monitor;

  function new(string name = "alu_tb_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    `uvm_info(get_full_name(), "Building...", UVM_LOW)

    driver    = alu_tb_driver    #( .REG_WIDTH(REG_WIDTH) ) ::type_id::create("driver", this);
    sequencer = alu_tb_sequencer #( .REG_WIDTH(REG_WIDTH) ) ::type_id::create("sequencer", this);
    monitor   = alu_tb_monitor   #( .REG_WIDTH(REG_WIDTH) ) ::type_id::create("monitor", this);
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    `uvm_info(get_full_name(), "Connecting...", UVM_LOW)
    driver.seq_item_port.connect(sequencer.seq_item_export);
  endfunction
endclass