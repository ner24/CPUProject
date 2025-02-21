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

import pkg_dtypes::*;
//`define FMT_BIT_WIDTH_STR(width) %``width``d
//`define ALU_ALLOC_FMT `FMT_BIT_WIDTH_STR(`LOG2_NUM_EXEC_UNITS)
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

  typedef uvm_enum_wrapper#(enum_instr_exec_unit) opcode_str_enum_caster;

  function new(string name = "test_0_sequence");
    super.new(name);
  endfunction

  function void create_instr_format_strs();
    `uvm_info("BACKEND_TEST0", "Creating instruction sformatf strings", UVM_MEDIUM)

    fmt_code_icon = "-2\ticonmv\t%d,%d,%d\t"; //"00,10,00,00,00,00,00,00,00,00,	True"
    for (int i = 0; i < 2**`LOG2_NUM_EXEC_UNITS; i++) begin
      fmt_code_icon = {fmt_code_icon, "%1b%1b,"};
    end
    fmt_code_icon = {fmt_code_icon, "\t%s\n"};

    fmt_code_reg_none = "%d\t%s\t%d,%d,%d\t%d,%d,%d\tNone\n";
    fmt_code_reg_reg = "%d\t%s\t%d,%d,%d\t%d,%d,%d\t%d,%d,%d\n";
    fmt_code_reg_imm = "%d\t%s\t%d,%d,%d\t%d,%d,%d\t#%d\n";
    fmt_code_imm_none = "%d\t%s\t%d,%d,%d\t#%d\tNone\n";
    fmt_code_imm_reg = "%d\t%s\t%d,%d,%d\t#%d\t%d,%d,%d\n";
    fmt_code_imm_imm = "%d\t%s\t%d,%d,%d\t#%d\t#%d\n";

  endfunction

  virtual task body();
    backend_sequence_item seq_item;
    int file, file_instr_formats;
    int read_result;

    logic [3:0] instruction_format;

    //points to the index within the parallel arrays where the instruction should go
    int instr_dispatch_ptr, icon_instr_dispatch_ptr, line_idx;
    localparam NUM_PARALLEL_INSTR_DISPATCHES = `NUM_PARALLEL_INSTR_DISPATCHES;
    localparam NUM_ICON_CHANNELS = 2**`LOG2_NUM_ICON_CHANNELS;

    logic [`LOG2_NUM_EXEC_UNITS-1:0] instr_dispatch_alloc_euidx  [NUM_PARALLEL_INSTR_DISPATCHES-1:0];
    type_iqueue_entry instr_dispatch            [NUM_PARALLEL_INSTR_DISPATCHES-1:0];
    logic instr_dispatch_valid                  [NUM_PARALLEL_INSTR_DISPATCHES-1:0];
    type_icon_instr icon_instr_dispatch [NUM_ICON_CHANNELS-1:0];
    logic icon_instr_dispatch_valid     [NUM_ICON_CHANNELS-1:0];

    string instr_file, instr_fmt_file;

    create_instr_format_strs();

    instr_file = `QUOTE_WRAP(`BACKEND_ASSEMBLY_TXT_PATH_WITHOUT_QUOTES);
    instr_fmt_file = {`QUOTE_WRAP(`BACKEND_ASSEMBLY_TXT_PATH_WITHOUT_QUOTES), "_formats.txt"};
    `uvm_info("BACKEND_TEST0", {"Opening file: ", instr_file}, UVM_MEDIUM)
    file = $fopen(instr_file, "r");
    if (file == 0) begin
      `uvm_fatal("BACKEND_TEST0", {"Failed to open ", instr_file})
    end
    `uvm_info("BACKEND_TEST0", {"Opening file: ", instr_fmt_file}, UVM_MEDIUM)
    file_instr_formats = $fopen(instr_fmt_file, "r");
    if (file_instr_formats == 0) begin
      `uvm_fatal("BACKEND_TEST0", {"Failed to open ", instr_fmt_file})
    end

    instr_dispatch_ptr = 'd0;
    icon_instr_dispatch_ptr = 'd0;

    line_idx = 'd0;
    while (!$feof(file_instr_formats)) begin
      read_result = $fscanf(file_instr_formats, "%b\n", instruction_format);
      if (read_result != 1) begin
        `uvm_fatal("BACKEND_TEST0", $sformatf("Failed to read instruction format at line %d", line_idx))
      end
      
      //instruction format codes: 4 signals, iconmv(1) or alu(0), op0m, op1v, op1m
      case (instruction_format)
        4'b1000: begin //icon instruction
          string invalSrcStr;
          read_result = $fscanf(file, fmt_code_icon,
            icon_instr_dispatch[icon_instr_dispatch_ptr].src_addr.euidx,
            icon_instr_dispatch[icon_instr_dispatch_ptr].src_addr.uid,
            icon_instr_dispatch[icon_instr_dispatch_ptr].src_addr.spec,

            //NOTE: for some stupid reason systemverilog does not have `if macros
            //LOG2_NUM_EXEC_UNITS >= 1
            icon_instr_dispatch[icon_instr_dispatch_ptr].receiver_list.eus[0],
            icon_instr_dispatch[icon_instr_dispatch_ptr].receiver_list.eus[1],
            icon_instr_dispatch[icon_instr_dispatch_ptr].receiver_list.eus[2],
            icon_instr_dispatch[icon_instr_dispatch_ptr].receiver_list.eus[3],
            
            //LOG2_NUM_EXEC_UNITS >= 2
            icon_instr_dispatch[icon_instr_dispatch_ptr].receiver_list.eus[4],
            icon_instr_dispatch[icon_instr_dispatch_ptr].receiver_list.eus[5],
            icon_instr_dispatch[icon_instr_dispatch_ptr].receiver_list.eus[6],
            icon_instr_dispatch[icon_instr_dispatch_ptr].receiver_list.eus[7],
            
            //LOG2_NUM_EXEC_UNITS == 3
            icon_instr_dispatch[icon_instr_dispatch_ptr].receiver_list.eus[8],
            icon_instr_dispatch[icon_instr_dispatch_ptr].receiver_list.eus[9],
            icon_instr_dispatch[icon_instr_dispatch_ptr].receiver_list.eus[10],
            icon_instr_dispatch[icon_instr_dispatch_ptr].receiver_list.eus[11],
            icon_instr_dispatch[icon_instr_dispatch_ptr].receiver_list.eus[12],
            icon_instr_dispatch[icon_instr_dispatch_ptr].receiver_list.eus[13],
            icon_instr_dispatch[icon_instr_dispatch_ptr].receiver_list.eus[14],
            icon_instr_dispatch[icon_instr_dispatch_ptr].receiver_list.eus[15],

            invalSrcStr
          );
          if (read_result != 1) begin
            `uvm_fatal("BACKEND_TEST0", $sformatf("Failed to read icon instr at line %d", line_idx))
          end

          icon_instr_dispatch_valid[icon_instr_dispatch_ptr] = 1'b1;

          icon_instr_dispatch_ptr = icon_instr_dispatch_ptr + 1;
          break;
        end

        4'b0100: begin
          string opcodeStr;
          read_result = $fscanf(file, fmt_code_reg_none,
            instr_dispatch_alloc_euidx[instr_dispatch_ptr],
            opcodeStr,
            instr_dispatch[instr_dispatch_ptr].opd.euidx,
            instr_dispatch[instr_dispatch_ptr].opd.uid,
            instr_dispatch[instr_dispatch_ptr].opd.spec,
            instr_dispatch[instr_dispatch_ptr].op0.as_addr.euidx,
            instr_dispatch[instr_dispatch_ptr].op0.as_addr.uid,
            instr_dispatch[instr_dispatch_ptr].op0.as_addr.spec
          );
          if (read_result != 1) begin
            `uvm_fatal("BACKEND_TEST0", $sformatf("Failed to read reg-none instr at line %d", line_idx))
          end

          //backend does not have an op1v flag (as its more or less embedded in the opcode)
          //so just add dummy immediate
          instr_dispatch[instr_dispatch_ptr].op1.as_imm.data = 'd0;
          instr_dispatch[instr_dispatch_ptr].op1m = IMM_OR_NONE;
          instr_dispatch[instr_dispatch_ptr].op0m = REG;
          if(opcode_str_enum_caster::from_name(opcodeStr, instr_dispatch[instr_dispatch_ptr].opcode.specific_instr))
            `uvm_fatal("BACKEND_TEST0", $sformatf("Failed to cast opcode (given string: %s) at line %d", opcodeStr, line_idx));
          instr_dispatch[instr_dispatch_ptr].opcode.exec_type = EXEC_UNIT;

          instr_dispatch_valid[instr_dispatch_ptr] = 1'b1;

          instr_dispatch_ptr = instr_dispatch_ptr + 1;
          break;
        end
        
        4'b0111: begin
          string opcodeStr;
          read_result = $fscanf(file, fmt_code_reg_reg,
            instr_dispatch_alloc_euidx[instr_dispatch_ptr],
            opcodeStr,
            instr_dispatch[instr_dispatch_ptr].opd.euidx,
            instr_dispatch[instr_dispatch_ptr].opd.uid,
            instr_dispatch[instr_dispatch_ptr].opd.spec,
            instr_dispatch[instr_dispatch_ptr].op0.as_addr.euidx,
            instr_dispatch[instr_dispatch_ptr].op0.as_addr.uid,
            instr_dispatch[instr_dispatch_ptr].op0.as_addr.spec,
            instr_dispatch[instr_dispatch_ptr].op1.as_addr.euidx,
            instr_dispatch[instr_dispatch_ptr].op1.as_addr.uid,
            instr_dispatch[instr_dispatch_ptr].op1.as_addr.spec
          );
          if (read_result != 1) begin
            `uvm_fatal("BACKEND_TEST0", $sformatf("Failed to read reg-reg instr at line %d", line_idx))
          end

          instr_dispatch[instr_dispatch_ptr].op0m = REG;
          instr_dispatch[instr_dispatch_ptr].op1m = REG;
          if(opcode_str_enum_caster::from_name(opcodeStr, instr_dispatch[instr_dispatch_ptr].opcode.specific_instr))
            `uvm_fatal("BACKEND_TEST0", $sformatf("Failed to cast opcode (given string: %s) at line %d", opcodeStr, line_idx));
          instr_dispatch[instr_dispatch_ptr].opcode.exec_type = EXEC_UNIT;

          instr_dispatch_valid[instr_dispatch_ptr] = 1'b1;

          instr_dispatch_ptr = instr_dispatch_ptr + 1;
          break;
        end

        4'b0110: begin
          string opcodeStr;
          read_result = $fscanf(file, fmt_code_reg_imm,
            instr_dispatch_alloc_euidx[instr_dispatch_ptr],
            opcodeStr,
            instr_dispatch[instr_dispatch_ptr].opd.euidx,
            instr_dispatch[instr_dispatch_ptr].opd.uid,
            instr_dispatch[instr_dispatch_ptr].opd.spec,
            instr_dispatch[instr_dispatch_ptr].op0.as_addr.euidx,
            instr_dispatch[instr_dispatch_ptr].op0.as_addr.uid,
            instr_dispatch[instr_dispatch_ptr].op0.as_addr.spec,
            instr_dispatch[instr_dispatch_ptr].op1.as_imm
          );
          if (read_result != 1) begin
            `uvm_fatal("BACKEND_TEST0", $sformatf("Failed to read reg-imm instr at line %d", line_idx))
          end

          instr_dispatch[instr_dispatch_ptr].op0m = REG;
          instr_dispatch[instr_dispatch_ptr].op1m = IMM_OR_NONE;
          if(opcode_str_enum_caster::from_name(opcodeStr, instr_dispatch[instr_dispatch_ptr].opcode.specific_instr))
            `uvm_fatal("BACKEND_TEST0", $sformatf("Failed to cast opcode (given string: %s) at line %d", opcodeStr, line_idx));
          instr_dispatch[instr_dispatch_ptr].opcode.exec_type = EXEC_UNIT;

          instr_dispatch_valid[instr_dispatch_ptr] = 1'b1;

          instr_dispatch_ptr = instr_dispatch_ptr + 1;
          break;
        end

        4'b0000: begin
          string opcodeStr;
          read_result = $fscanf(file, fmt_code_imm_none,
            instr_dispatch_alloc_euidx[instr_dispatch_ptr],
            opcodeStr,
            instr_dispatch[instr_dispatch_ptr].opd.euidx,
            instr_dispatch[instr_dispatch_ptr].opd.uid,
            instr_dispatch[instr_dispatch_ptr].opd.spec,
            instr_dispatch[instr_dispatch_ptr].op0.as_imm
          );
          if (read_result != 1) begin
            `uvm_fatal("BACKEND_TEST0", $sformatf("Failed to read imm-none instr at line %d", line_idx))
          end

          //backend does not have an op1v flag (as its more or less embedded in the opcode)
          //so just add dummy immediate
          instr_dispatch[instr_dispatch_ptr].op1.as_imm.data = 'd0;
          instr_dispatch[instr_dispatch_ptr].op0m = IMM_OR_NONE;
          instr_dispatch[instr_dispatch_ptr].op1m = IMM_OR_NONE;
          if(opcode_str_enum_caster::from_name(opcodeStr, instr_dispatch[instr_dispatch_ptr].opcode.specific_instr))
            `uvm_fatal("BACKEND_TEST0", $sformatf("Failed to cast opcode (given string: %s) at line %d", opcodeStr, line_idx));
          instr_dispatch[instr_dispatch_ptr].opcode.exec_type = EXEC_UNIT;

          instr_dispatch_valid[instr_dispatch_ptr] = 1'b1;

          instr_dispatch_ptr = instr_dispatch_ptr + 1;
          break;
        end

        4'b0011: begin
          string opcodeStr;
          read_result = $fscanf(file, fmt_code_imm_reg,
            instr_dispatch_alloc_euidx[instr_dispatch_ptr],
            opcodeStr,
            instr_dispatch[instr_dispatch_ptr].opd.euidx,
            instr_dispatch[instr_dispatch_ptr].opd.uid,
            instr_dispatch[instr_dispatch_ptr].opd.spec,
            instr_dispatch[instr_dispatch_ptr].op0.as_imm,
            instr_dispatch[instr_dispatch_ptr].op1.as_addr.euidx,
            instr_dispatch[instr_dispatch_ptr].op1.as_addr.uid,
            instr_dispatch[instr_dispatch_ptr].op1.as_addr.spec
          );
          if (read_result != 1) begin
            `uvm_fatal("BACKEND_TEST0", $sformatf("Failed to read imm-reg instr at line %d", line_idx))
          end

          instr_dispatch[instr_dispatch_ptr].op0m = IMM_OR_NONE;
          instr_dispatch[instr_dispatch_ptr].op1m = REG;
          if(opcode_str_enum_caster::from_name(opcodeStr, instr_dispatch[instr_dispatch_ptr].opcode.specific_instr))
            `uvm_fatal("BACKEND_TEST0", $sformatf("Failed to cast opcode (given string: %s) at line %d", opcodeStr, line_idx));
          instr_dispatch[instr_dispatch_ptr].opcode.exec_type = EXEC_UNIT;

          instr_dispatch_valid[instr_dispatch_ptr] = 1'b1;

          instr_dispatch_ptr = instr_dispatch_ptr + 1;
          break;
        end

        4'b0010: begin
          string opcodeStr;
          read_result = $fscanf(file, fmt_code_imm_imm,
            instr_dispatch_alloc_euidx[instr_dispatch_ptr],
            opcodeStr,
            instr_dispatch[instr_dispatch_ptr].opd.euidx,
            instr_dispatch[instr_dispatch_ptr].opd.uid,
            instr_dispatch[instr_dispatch_ptr].opd.spec,
            instr_dispatch[instr_dispatch_ptr].op0.as_imm,
            instr_dispatch[instr_dispatch_ptr].op1.as_imm
          );
          if (read_result != 1) begin
            `uvm_fatal("BACKEND_TEST0", $sformatf("Failed to read imm-imm instr at line %d", line_idx))
          end

          instr_dispatch[instr_dispatch_ptr].op0m = IMM_OR_NONE;
          instr_dispatch[instr_dispatch_ptr].op1m = IMM_OR_NONE;
          if(opcode_str_enum_caster::from_name(opcodeStr, instr_dispatch[instr_dispatch_ptr].opcode.specific_instr))
            `uvm_fatal("BACKEND_TEST0", $sformatf("Failed to cast opcode (given string: %s) at line %d", opcodeStr, line_idx));
          instr_dispatch[instr_dispatch_ptr].opcode.exec_type = EXEC_UNIT;

          instr_dispatch_valid[instr_dispatch_ptr] = 1'b1;

          instr_dispatch_ptr = instr_dispatch_ptr + 1;
          break;
        end

        default: `uvm_fatal("BACKEND_TEST0", $sformatf("Unrecognised format code: %b", instruction_format))
      endcase

      //note that if num icon instructions held = num icon channels, only dispatch
      //icon instructions and not the normal one, if the batch is filled, both normal and icon
      //instructions should be dispatched
      if (instr_dispatch_ptr == NUM_PARALLEL_INSTR_DISPATCHES) begin
        seq_item = backend_sequence_item::type_id::create("seq_item");
        
        start_item(seq_item);
        seq_item.instr_dispatch_i = instr_dispatch;
        seq_item.instr_dispatch_valid_i = instr_dispatch_valid;
        seq_item.dispatched_instr_alloc_euidx_i = instr_dispatch_alloc_euidx;

        seq_item.icon_instr_dispatch_i = icon_instr_dispatch;
        seq_item.icon_instr_dispatch_valid_i = icon_instr_dispatch_valid;
        finish_item(seq_item);
        
        instr_dispatch_ptr = 'd0;
      end else if (icon_instr_dispatch_ptr == NUM_ICON_CHANNELS) begin
        seq_item = backend_sequence_item::type_id::create("seq_item");
        start_item(seq_item);

        for(int g_parallel_dist = 0; g_parallel_dist < NUM_PARALLEL_INSTR_DISPATCHES; g_parallel_dist++) begin
          seq_item.instr_dispatch_valid_i[g_parallel_dist] = 'b0;
        end
        
        seq_item.icon_instr_dispatch_i = icon_instr_dispatch;
        seq_item.icon_instr_dispatch_valid_i = icon_instr_dispatch_valid;
        finish_item(seq_item);
        icon_instr_dispatch_ptr = 'd0;
      end
      
      line_idx = line_idx + 1;
    end
    
    // Close the file
    $fclose(file);

    //dispatch the remaining icon and normal instructions
    seq_item = backend_sequence_item::type_id::create("seq_item");
    start_item(seq_item);
    seq_item.instr_dispatch_i = instr_dispatch;
    seq_item.instr_dispatch_valid_i = instr_dispatch_valid;
    seq_item.dispatched_instr_alloc_euidx_i = instr_dispatch_alloc_euidx;

    seq_item.icon_instr_dispatch_i = icon_instr_dispatch;
    seq_item.icon_instr_dispatch_valid_i = icon_instr_dispatch_valid;
    finish_item(seq_item);

    //next steps do nothing
    //its just to delay the $finish call
    for (int step = 0; step < 10; step++) begin
      seq_item = backend_sequence_item::type_id::create("seq_item");
      start_item(seq_item);
      for(int i = 0; i < NUM_ICON_CHANNELS; i++) begin
        seq_item.icon_instr_dispatch_valid_i[i] = 'b0;
      end
      for(int i = 0; i < NUM_PARALLEL_INSTR_DISPATCHES; i++) begin
        seq_item.instr_dispatch_valid_i[i] = 'b0;
      end
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
