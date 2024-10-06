import uvm_pkg::*;
`include "uvm_macros.svh"
`include "alu_tb_sequence_item.sv"

class alu_tb_monitor #(
    parameter REG_WIDTH = 4
) extends uvm_monitor;

  // Factory Registration
  `uvm_component_param_utils(alu_tb_monitor#( .REG_WIDTH(REG_WIDTH) ))

  // Variables
  alu_tb_sequence_item #(
    .REG_WIDTH(REG_WIDTH)
  ) sequence_item;

  virtual alu_dut_intf #(
    .REG_WIDTH(REG_WIDTH)
  ) vintf;

  // Analysis Port
  uvm_analysis_port #(alu_tb_sequence_item #( .REG_WIDTH(REG_WIDTH) )) analysis_port;

  // Tasks and Functions

  function new(string name = "test_design_monitor", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    `uvm_info(get_full_name(), "Building...", UVM_LOW)
    if(!uvm_config_db#(virtual alu_dut_intf #( .REG_WIDTH(REG_WIDTH) ))::get(this, "", "intf_alu", vintf)) begin
      `uvm_fatal(get_type_name(), " Couldn't get vintf, check uvm config for interface?")
    end
    analysis_port = new("alu_tb_analysis_port", this);
  endfunction

  virtual task run_phase(uvm_phase phase);
    alu_tb_sequence_item #(
      .REG_WIDTH(REG_WIDTH)
    ) sequence_item;
    sequence_item = alu_tb_sequence_item#( .REG_WIDTH(REG_WIDTH) )::type_id::create("sequence_item");

    forever begin
      @(posedge vintf.clk);

      sequence_item.a     <= vintf.a_i;
      sequence_item.b     <= vintf.b_i;
      sequence_item.instr <= vintf.instr_i;
      sequence_item.out   <= vintf.out_o;
      
      analysis_port.write(sequence_item);
      
      `uvm_info(get_full_name(), "Written Sequence Item from Monitor", UVM_DEBUG)
    end
  endtask
endclass