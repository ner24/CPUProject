import uvm_pkg::*;
`include "uvm_macros.svh"
`include "alu_tb_sequence_item.sv"

class alu_tb_driver #(
  parameter REG_WIDTH = 4
) extends uvm_driver #(alu_tb_sequence_item #( .REG_WIDTH(REG_WIDTH) ));

  `uvm_component_param_utils(alu_tb_driver#( .REG_WIDTH(REG_WIDTH) ))

  virtual alu_dut_intf #(
    .REG_WIDTH(REG_WIDTH)
  ).DRIVER_SIDE vintf;
  
  function new(string name = "test_design_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    `uvm_info(get_full_name(), "Building...", UVM_LOW)
    super.build_phase(phase);
    if(!uvm_config_db#( virtual alu_dut_intf #(.REG_WIDTH(REG_WIDTH)) .DRIVER_SIDE )::get(this, "", "intf_alu_driver_side", vintf)) begin
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

  virtual task drive(alu_tb_sequence_item #( .REG_WIDTH(REG_WIDTH) ) seq_item);
    vintf.a_i     <= seq_item.a;
    vintf.b_i     <= seq_item.b;
    vintf.instr_i <= seq_item.instr;
    vintf.cin_i   <= '0;

    vintf.out_o   <= seq_item.out[REG_WIDTH-1:0];
    vintf.cout_o  <= seq_item.out[REG_WIDTH];
  endtask
endclass