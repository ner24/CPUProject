import uvm_pkg::*;
`include "uvm_macros.svh"

`include "../../../config/alu_parameters.sv"

`include "../testbench/agent/alu_tb_sequence_item.sv"
`include "../testbench/alu_tb_env.sv"

class test_operations_sequence #(
  parameter REG_WIDTH = 4
) extends uvm_sequence#(alu_tb_sequence_item #( .REG_WIDTH(REG_WIDTH) ));

  `uvm_object_param_utils(test_operations_sequence#( .REG_WIDTH(REG_WIDTH) ))

  function new(string name = "test_operations_sequence");
    super.new(name);
  endfunction

  virtual task body();
    alu_tb_sequence_item #(
      .REG_WIDTH(REG_WIDTH)
    ) sequence_item;

    `uvm_info(get_full_name(), "Starting test...", UVM_LOW)

    for (logic[3:0] i = 0; i <= 4'd8; i++) begin
      for (int j = 0; j < 10; j++) begin
      //repeat(10) begin
        sequence_item = alu_tb_sequence_item#( .REG_WIDTH(REG_WIDTH) )::type_id::create("sequence_item");
        start_item(sequence_item);
        sequence_item.instr = i;
        assert (sequence_item.randomize());
        finish_item(sequence_item);
      end
    end
  endtask

endclass

class test_operations extends uvm_test;
  `uvm_component_utils(test_operations)
  //`uvm_component_registry(test_operations#( .REG_WIDTH(REG_WIDTH) ), "test_operations")

  localparam REG_WIDTH = `ALU_REG_WIDTH;

  alu_tb_env #(
    .REG_WIDTH(REG_WIDTH)
  ) env;

  test_operations_sequence #(
    .REG_WIDTH(REG_WIDTH)
  ) test_sequence;

  function new(string name = "test_operations", uvm_component parent=null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    env = alu_tb_env #( .REG_WIDTH(REG_WIDTH) )::type_id::create("env", this);
  endfunction

  virtual task run_phase(uvm_phase phase);
    super.run_phase(phase);
    phase.raise_objection(this);

    `uvm_info(get_full_name(), "Starting operations test", UVM_MEDIUM)
    test_sequence = test_operations_sequence#( .REG_WIDTH(REG_WIDTH) )::type_id::create("test_sequence");
    test_sequence.start(env.agent.sequencer);

    phase.drop_objection(this);
  endtask
endclass