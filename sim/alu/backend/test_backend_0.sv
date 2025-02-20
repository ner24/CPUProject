`ifndef BACKEND_TEST_0_INCLUDE
`define BACKEND_TEST_0_INCLUDE

import uvm_pkg::*;
`include "uvm_macros.svh"

`include "agent_backend.sv"
`include "design_parameters.sv"
`include "simulation_parameters.sv"

class backend_env_test_0 extends uvm_env;
  `uvm_component_utils(backend_env_test_0)

  backend_agent agent;

  function new (string name = "backend_env_test_0", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    `uvm_info(get_full_name(), "Building exec unit env...", UVM_LOW)
    agent = backend_agent::type_id::create("agent", this);
  endfunction

  virtual function void connect_phase(uvm_phase phase);

  endfunction
endclass

class test_0_sequence extends uvm_sequence#(backend_sequence_item);

  `uvm_object_utils(test_0_sequence)

  //possible format codes from front end
  string  fmt_code_icon,
          fmt_code_reg_none,
          fmt_code_reg_reg,
          fmt_code_reg_imm,
          fmt_code_imm_none,
          fmt_code_imm_reg,
          fmt_code_imm_imm;

  function new(string name = "test_0_sequence");
    super.new(name);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    
  endfunction

  virtual task body();
    backend_sequence_item seq_item;
    int file, file_instr_formats;
    int read_result;

    file = $fopen(`BACKEND_ASSEMBLY_TXT_PATH, "r");
    file_instr_formats = $fopen(`BACKEND_ASSEMBLY_TXT_PATH + "_formats.txt", "r");
    if (file == 0) begin
      `uvm_fatal("BACKEND_TEST0", "Cannot open file")
    end

    while (!$feof(file_instr_formats)) begin
      logic [3:0] instruction_format;
      int alu_alloc;
      string opcode;
      int opd[3];

      read_result = $fscanf(file, "%b\n", instruction_format);
      if (read_result != 1) begin
        `uvm_fatal("BACKEND_TEST0", "Failed to read instruction format. Possible bad format")
      end

      seq_item = backend_sequence_item::type_id::create("seq_item", this);
      case (instruction_format)
        //instruction format codes: 4 signals, iconmv(1) or alu(0), op0m, op1v, op1m
        4'b1000: begin //icon instruction

        end
        default: `uvm_fatal("BACKEND_TEST0", $sformatf("Unrecognised format code: %b", instruction_format))
      endcase
      read_result = $fscanf(file, "%s\t%s\t%s\t%s\t%s\n", data_read);
      if (read_result == 1) begin
        start_item(item);
        item.data = data_read;
        finish_item(item);
      end else begin
        //if bad format, then probably iconmv function
        read_result = $fscanf(file, "%s\t%s\t%s\t%s\t%s\n", data_read);
        //`uvm_fatal("BACKEND_TEST0", "Failed to read file. Possible bad format")
        break;
      end
    end

    // Close the file
    $fclose(file);

    //next steps do nothing
    //its just to delay the $finish call
    for (int step = 0; step < 10; step++) begin
      seq_item = backend_sequence_item::type_id::create("sequence_item");
      start_item(seq_item);
      seq_item.icon_rx0_i.valid = 'b0;
      seq_item.icon_rx1_i.valid = 'b0;
      for(int i = 0; i < `NUM_PARALLEL_INSTR_DISPATCHES; i++) begin
        seq_item.dispatched_instr_valid_i[i] = 'b0;
      end
      seq_item.icon_tx_req_valid_i = 'b0;
      finish_item(seq_item);
    end
  endtask

endclass

class backend_test_0 extends uvm_test;
  `uvm_component_utils(backend_test_0)

  backend_env_test_0 env;
  test_0_sequence test_sequence;

  function new(string name = "backend_test_0", uvm_component parent=null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    env = backend_env_test_0::type_id::create("env", this);
  endfunction

  virtual task run_phase(uvm_phase phase);
    super.run_phase(phase);
    phase.raise_objection(this);

    test_sequence = test_0_sequence::type_id::create("test_sequence");
    test_sequence.start(env.agent.sequencer);

    phase.drop_objection(this);
  endtask
endclass

`endif //include guard
