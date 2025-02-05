`ifndef EU_TEST_GENERAL_INCLUDE
`define EU_TEST_GENERAL_INCLUDE

import uvm_pkg::*;
`include "uvm_macros.svh"

`include "../agent_exec_unit.sv"

class execution_unit_env extends uvm_env;
  `uvm_component_utils(execution_unit_env)

  execution_unit_agent agent;

  function new (string name = "execution_unit_env", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    `uvm_info(get_full_name(), "Building exec unit env...", UVM_LOW)
    agent = execution_unit_agent::type_id::create("agent", this);
  endfunction

  virtual function void connect_phase(uvm_phase phase);

  endfunction
endclass

class test_general_sequence extends uvm_sequence#(execution_unit_sequence_item);

  `uvm_object_utils(test_general_sequence)

  function new(string name = "test_general_sequence");
    super.new(name);
  endfunction

  virtual task body();
    execution_unit_sequence_item seq_item;

    `uvm_info(get_full_name(), "Starting test...", UVM_LOW)
    seq_item = execution_unit_sequence_item::type_id::create("sequence_item");
    start_item(seq_item);

    seq_item.icon_rx0_i      = '{default: 'b0};
    seq_item.icon_rx1_i      = 'b0;
    
    seq_item.icon_tx_addr_i      = 'b0;
    seq_item.icon_tx_req_valid_i = 'b0;

    seq_item.dispatched_instr_i       = 'b0;
    seq_item.dispatched_instr_valid_i = 'b0;
      
    finish_item(seq_item);
  endtask

endclass

class execution_unit_test_general extends uvm_test;
  `uvm_component_utils(execution_unit_test_general)

  execution_unit_env env;
  test_general_sequence test_sequence;

  function new(string name = "execution_unit_test_general", uvm_component parent=null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    env = execution_unit_env::type_id::create("env", this);
  endfunction

  virtual task run_phase(uvm_phase phase);
    super.run_phase(phase);
    phase.raise_objection(this);

    test_sequence = test_general_sequence::type_id::create("test_sequence");
    test_sequence.start(env.agent.sequencer);

    phase.drop_objection(this);
  endtask
endclass

`endif //include guard
