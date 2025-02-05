`ifndef EU_TEST_RX0_ADD_RX1_INCLUDE
`define EU_TEST_RX0_ADD_RX1_INCLUDE

import uvm_pkg::*;
`include "uvm_macros.svh"

`include "../agent_exec_unit.sv"

class execution_unit_env_test_rx0_add_rx1 extends uvm_env;
  `uvm_component_utils(execution_unit_env_test_rx0_add_rx1)

  execution_unit_agent agent;

  function new (string name = "execution_unit_env_test_rx0_add_rx1", uvm_component parent = null);
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

class test_rx0_add_rx1_sequence extends uvm_sequence#(execution_unit_sequence_item);

  `uvm_object_utils(test_rx0_add_rx1_sequence)

  function new(string name = "test_rx0_add_rx1_sequence");
    super.new(name);
  endfunction

  virtual task body();
    execution_unit_sequence_item seq_item;

    `uvm_info(get_full_name(), "Building Rx0 add Rx1 test sequence...", UVM_LOW)
    for (int step = 0; step < 1; step++) begin
      seq_item = execution_unit_sequence_item::type_id::create("sequence_item");
      start_item(seq_item);
      case (step)
        0: begin
          //rx0
          seq_item.icon_rx0_i.addr.euidx = 'd1;
          seq_item.icon_rx0_i.addr.uid = 'd0;
          seq_item.icon_rx0_i.addr.spec = 'd2;
          
          seq_item.icon_rx0_i.data.data = 'd30;
          seq_item.icon_rx0_i.valid = 'b1;

          //rx1
          seq_item.icon_rx1_i.addr.euidx = 'd2;
          seq_item.icon_rx1_i.addr.uid = 'd0;
          seq_item.icon_rx1_i.addr.spec = 'd1;

          seq_item.icon_rx1_i.data.data = 'd46;
          seq_item.icon_rx1_i.valid = 'b1;
          
          //instruction will be passed in step 0
          //exec unit should hold it until next cycle
          //since rxx dont have 0 cycle shortcuts atm
          seq_item.dispatched_instr_valid_i = 'b1;
          seq_item.dispatched_instr_i.op0m = REG;
          seq_item.dispatched_instr_i.op1m = REG;

          seq_item.dispatched_instr_i.opcode.exec_type = EXEC_UNIT;
          seq_item.dispatched_instr_i.opcode.specific_instr = enum_instr_exec_unit'(ADD);

          seq_item.dispatched_instr_i.op0.as_addr.euidx = 'd1;
          seq_item.dispatched_instr_i.op0.as_addr.uid = 'd0;
          seq_item.dispatched_instr_i.op0.as_addr.spec = 'd2;

          seq_item.dispatched_instr_i.op1.as_addr.euidx = 'd2;
          seq_item.dispatched_instr_i.op1.as_addr.uid = 'd0;
          seq_item.dispatched_instr_i.op1.as_addr.spec = 'd1;

          seq_item.dispatched_instr_i.opd.euidx = 'd0; //means result should be in ybuffer
          seq_item.dispatched_instr_i.opd.uid = 'd0;
          seq_item.dispatched_instr_i.opd.spec = 'd3;

          //no tx req in this test
          seq_item.icon_tx_req_valid_i = 'b0;
        end

        default: begin
          `uvm_warning("TESTWARN0", "Step out of range")
        end
      endcase
      finish_item(seq_item);
    end

    //next steps do nothing
    //its just to delay the $finish call
    for (int step = 0; step < 10; step++) begin
      seq_item = execution_unit_sequence_item::type_id::create("sequence_item");
      start_item(seq_item);
      seq_item.icon_rx0_i.valid = 'b0;
      seq_item.icon_rx1_i.valid = 'b0;
      seq_item.dispatched_instr_valid_i = 'b0;
      seq_item.icon_tx_req_valid_i = 'b0;
      finish_item(seq_item);
    end
  endtask

endclass

class execution_unit_test_rx0_add_rx1 extends uvm_test;
  `uvm_component_utils(execution_unit_test_rx0_add_rx1)

  execution_unit_env_test_rx0_add_rx1 env;
  test_rx0_add_rx1_sequence test_sequence;

  function new(string name = "execution_unit_test_rx0_add_rx1", uvm_component parent=null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    env = execution_unit_env_test_rx0_add_rx1::type_id::create("env", this);
  endfunction

  virtual task run_phase(uvm_phase phase);
    super.run_phase(phase);
    phase.raise_objection(this);

    test_sequence = test_rx0_add_rx1_sequence::type_id::create("test_sequence");
    test_sequence.start(env.agent.sequencer);

    phase.drop_objection(this);
  endtask
endclass

`endif //include guard
