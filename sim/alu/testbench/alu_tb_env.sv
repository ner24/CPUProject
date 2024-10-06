import uvm_pkg::*;
`include "uvm_macros.svh"
`include "agent/alu_tb_agent.sv"

class alu_tb_env #(
  parameter REG_WIDTH = 4
) extends uvm_env;
  `uvm_component_utils(alu_tb_env #(.REG_WIDTH(REG_WIDTH)) )

  alu_tb_agent #(
    .REG_WIDTH(REG_WIDTH)
  ) agent;
  //test_design_cov alu_tb_coverage; //WIP

  function new (string name = "alu_tb_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    `uvm_info(get_full_name(), "Building...", UVM_LOW)
    agent = alu_tb_agent #(.REG_WIDTH(REG_WIDTH)) ::type_id::create("agent", this);
  endfunction

  virtual function void connect_phase(uvm_phase phase);

  endfunction
endclass
