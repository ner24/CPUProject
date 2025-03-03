`ifndef ALPU_TEST_OPERATIONS_INCLUDE
`define ALPU_TEST_OPERATIONS_INCLUDE

import uvm_pkg::*;
`include "uvm_macros.svh"

`include "design_parameters.sv"

`include "agent_alu.sv"

class alu_env extends uvm_env;
  `uvm_component_utils(alu_env)

  alu_agent agent;

  function new (string name = "alpu_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    `uvm_info(get_full_name(), "Building...", UVM_LOW)
    agent = alu_agent::type_id::create("agent", this);
  endfunction

  virtual function void connect_phase(uvm_phase phase);

  endfunction
endclass

class test_operations_sequence extends uvm_sequence#(alu_sequence_item);
  `uvm_object_param_utils(test_operations_sequence)

  function new(string name = "test_operations_sequence");
    super.new(name);
  endfunction

  virtual task body();
    enum_instr_exec_unit opcode_enum;
    alu_sequence_item seq_item;

    `uvm_info(get_full_name(), "Starting test...", UVM_LOW)

    for (logic[LOG2_NUM_INSTRUCTIONS_PER_EXEC_TYPE-1:0] i = 0; i < opcode_enum.num(); i++) begin
      for (int j = 0; j < 10; j++) begin
        seq_item = alu_sequence_item::type_id::create("sequence_item");
        start_item(seq_item);
        
        seq_item.reset_n = 1'b1;
        seq_item.opcode_from_driver = i;
        seq_item.op1_data_from_driver = j;
        seq_item.op0_data_from_driver = j + 'd1;
        seq_item.randomize();

        finish_item(seq_item);
      end
    end
  endtask

endclass

class test_operations extends uvm_test;
  `uvm_component_utils(test_operations)

  alu_env env;
  test_operations_sequence test_sequence;

  function new(string name = "test_operations", uvm_component parent=null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    env = alu_env::type_id::create("env", this);
  endfunction

  virtual task run_phase(uvm_phase phase);
    super.run_phase(phase);
    phase.raise_objection(this);

    `uvm_info(get_full_name(), "Starting operations test", UVM_MEDIUM)
    test_sequence = test_operations_sequence::type_id::create("test_sequence");
    test_sequence.start(env.agent.sequencer);

    phase.drop_objection(this);
  endtask
endclass

`endif //include guard
