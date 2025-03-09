`ifndef BACKEND_TEST_0_INCLUDE
`define BACKEND_TEST_0_INCLUDE

import uvm_pkg::*;
`include "uvm_macros.svh"

`include "agent_backend.sv"
`include "design_parameters.sv"
`include "simulation_parameters.sv"
`include "user_parameters.sv"

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

  //typedef uvm_enum_wrapper#(enum_instr_exec_unit) opcode_str_enum_caster;

  function new(string name = "test_0_sequence");
    super.new(name);
  endfunction

  function enum_instr_exec_unit conv_opc_str_to_enum(string opcodeStr);
    case (opcodeStr)
      "MVN": return MVN;
      "AND": return AND;
      "ORR": return ORR;
      "XOR": return XOR;
      "ADD": return ADD;
      "SUB": return SUB;
      "NAND": return NAND;
      "NOR": return NOR;
      "XNOR": return XNOR;
      "LSR": return LSR;
      "LSL": return LSL;
      default: `uvm_fatal("BACKEND_TEST0", $sformatf("No enum conversion defined for: %s", opcodeStr))
    endcase
  endfunction

  function void create_instr_format_strs();
    `uvm_info("BACKEND_TEST0", "Creating instruction sformatf strings", UVM_MEDIUM)

    fmt_code_icon = "-2\ticonmv\t%d,%d,%d\t";
    for (int i = 0; i < 2**`LOG2_NUM_EXEC_UNITS; i++) begin
      fmt_code_icon = {fmt_code_icon, "%1b%1b,"};
    end
    fmt_code_icon = {fmt_code_icon, "\t%4s\n"};
    //`uvm_info("BACKEND_TEST0", fmt_code_icon, UVM_MEDIUM)

    fmt_code_reg_none = "%d\t%3s\t%d,%d,%d\t%d,%d,%d\tNone\n";
    fmt_code_reg_reg = "%d\t%3s\t%d,%d,%d\t%d,%d,%d\t%d,%d,%d\n";
    fmt_code_reg_imm = "%d\t%3s\t%d,%d,%d\t%d,%d,%d\t#%d\n";
    fmt_code_imm_none = "%d\t%3s\t%d,%d,%d\t#%d\tNone\n";
    fmt_code_imm_reg = "%d\t%3s\t%d,%d,%d\t#%d\t%d,%d,%d\n";
    fmt_code_imm_imm = "%d\t%3s\t%d,%d,%d\t#%d\t#%d\n";
    //fmt_code_imm_imm = "%d\n";

  endfunction

  localparam NUM_PARALLEL_INSTR_DISPATCHES = `NUM_PARALLEL_INSTR_DISPATCHES;
  localparam NUM_ICON_CHANNELS = 2**`LOG2_NUM_ICON_CHANNELS;
  localparam LOG2_NUM_EXEC_UNITS = `LOG2_NUM_EXEC_UNITS;
  localparam NUM_EXEC_UNITS = 2**LOG2_NUM_EXEC_UNITS;
  localparam NUM_BATCHES = 3; //set to some value that is larger than actual number of batches (since cannot be found at compile time)
  localparam NUM_ICON_BATCHES = 2;
  localparam EU_LOG2_IQUEUE_NUM_QUEUES = `EU_LOG2_IQUEUE_NUM_QUEUES;
  localparam EU_IQUEUE_NUM_QUEUES = 2**EU_LOG2_IQUEUE_NUM_QUEUES;

  logic [LOG2_NUM_EXEC_UNITS-1:0] instr_dispatch_alloc_euidx [NUM_BATCHES-1:0] [NUM_PARALLEL_INSTR_DISPATCHES-1:0];
  type_iqueue_entry instr_dispatch            [NUM_BATCHES-1:0] [NUM_PARALLEL_INSTR_DISPATCHES-1:0];
  logic instr_dispatch_valid                  [NUM_BATCHES-1:0] [NUM_PARALLEL_INSTR_DISPATCHES-1:0];
  type_icon_instr icon_instr_dispatch [NUM_BATCHES-1:0] [NUM_ICON_BATCHES-1:0] [NUM_ICON_CHANNELS-1:0];
  logic icon_instr_dispatch_valid     [NUM_BATCHES-1:0] [NUM_ICON_BATCHES-1:0] [NUM_ICON_CHANNELS-1:0];
  int   icon_batch_ptrs [NUM_BATCHES-1:0];

  virtual task pre_body();
    int file, file_instr_formats;
    int read_result;

    logic [3:0] instruction_format;

    //points to the index within the parallel arrays where the instruction should go
    int instr_dispatch_ptr, icon_instr_dispatch_ptr, line_idx, batch_idx;
    //int total_num_lines;
    string instr_file, instr_fmt_file;

    create_instr_format_strs();

    //set default valids to all zeros
    for (int i = 0; i < NUM_BATCHES; i++) begin
      for (int j = 0; j < NUM_PARALLEL_INSTR_DISPATCHES; j++) begin
        instr_dispatch_valid[i][j] = 'b0;
      end
      for (int j = 0; j < NUM_ICON_BATCHES; j++) begin
        for (int k = 0; k < NUM_ICON_CHANNELS; k++) begin
          icon_instr_dispatch_valid[i][j][k] = 'b0;
        end
      end
    end

    instr_file = `BACKEND_ASSEMBLY_TXT_PATH;
    instr_fmt_file = {`BACKEND_ASSEMBLY_TXT_PATH, "_formats.txt"};
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
    batch_idx = 'd0;
    for (int i = 0; i < NUM_BATCHES; i++) begin
      icon_batch_ptrs[i] = 'd0;
    end

    `uvm_info("BACKEND_TEST0", "Reading in instructions", UVM_MEDIUM)
    line_idx = 'd1;
    while (!$feof(file_instr_formats)) begin
    //while ($fscanf(file_instr_formats, "%4b\n", instruction_format)) begin
      read_result = $fscanf(file_instr_formats, "%4b\n", instruction_format);
      if (read_result != 1) begin
        `uvm_fatal("BACKEND_TEST0", $sformatf("Failed to read instruction format at line %d", line_idx))
      end
      `uvm_info("BACKEND_TEST0", $sformatf("Line %0d instruction format code: %4b", line_idx, instruction_format), UVM_MEDIUM)
      
      //instruction format codes: 4 signals, iconmv(1) or alu(0), op0m, op1v, op1m
      case (instruction_format)
        4'b1000: begin
          string invalSrcStr;
          `uvm_info("BACKEND_TEST0", "Reading instruction type: icon", UVM_MEDIUM)
          read_result = $fscanf(file, fmt_code_icon,
            icon_instr_dispatch[batch_idx][icon_batch_ptrs[batch_idx]][icon_instr_dispatch_ptr].src_addr.euidx,
            icon_instr_dispatch[batch_idx][icon_batch_ptrs[batch_idx]][icon_instr_dispatch_ptr].src_addr.uid,
            icon_instr_dispatch[batch_idx][icon_batch_ptrs[batch_idx]][icon_instr_dispatch_ptr].src_addr.spec,

            //NOTE: for some stupid reason systemverilog does not have `if macros
            //LOG2_NUM_EXEC_UNITS >= 1
            icon_instr_dispatch[batch_idx][icon_batch_ptrs[batch_idx]][icon_instr_dispatch_ptr].receiver_list.eus[0],
            icon_instr_dispatch[batch_idx][icon_batch_ptrs[batch_idx]][icon_instr_dispatch_ptr].receiver_list.eus[1],
            icon_instr_dispatch[batch_idx][icon_batch_ptrs[batch_idx]][icon_instr_dispatch_ptr].receiver_list.eus[2],
            icon_instr_dispatch[batch_idx][icon_batch_ptrs[batch_idx]][icon_instr_dispatch_ptr].receiver_list.eus[3],
            
            //LOG2_NUM_EXEC_UNITS >= 2
            icon_instr_dispatch[batch_idx][icon_batch_ptrs[batch_idx]][icon_instr_dispatch_ptr].receiver_list.eus[4],
            icon_instr_dispatch[batch_idx][icon_batch_ptrs[batch_idx]][icon_instr_dispatch_ptr].receiver_list.eus[5],
            icon_instr_dispatch[batch_idx][icon_batch_ptrs[batch_idx]][icon_instr_dispatch_ptr].receiver_list.eus[6],
            icon_instr_dispatch[batch_idx][icon_batch_ptrs[batch_idx]][icon_instr_dispatch_ptr].receiver_list.eus[7],
            
            //LOG2_NUM_EXEC_UNITS == 3
            icon_instr_dispatch[batch_idx][icon_batch_ptrs[batch_idx]][icon_instr_dispatch_ptr].receiver_list.eus[8],
            icon_instr_dispatch[batch_idx][icon_batch_ptrs[batch_idx]][icon_instr_dispatch_ptr].receiver_list.eus[9],
            icon_instr_dispatch[batch_idx][icon_batch_ptrs[batch_idx]][icon_instr_dispatch_ptr].receiver_list.eus[10],
            icon_instr_dispatch[batch_idx][icon_batch_ptrs[batch_idx]][icon_instr_dispatch_ptr].receiver_list.eus[11],
            icon_instr_dispatch[batch_idx][icon_batch_ptrs[batch_idx]][icon_instr_dispatch_ptr].receiver_list.eus[12],
            icon_instr_dispatch[batch_idx][icon_batch_ptrs[batch_idx]][icon_instr_dispatch_ptr].receiver_list.eus[13],
            icon_instr_dispatch[batch_idx][icon_batch_ptrs[batch_idx]][icon_instr_dispatch_ptr].receiver_list.eus[14],
            icon_instr_dispatch[batch_idx][icon_batch_ptrs[batch_idx]][icon_instr_dispatch_ptr].receiver_list.eus[15],

            invalSrcStr
          );
          //this test does not use the MMU at all
          icon_instr_dispatch[batch_idx][icon_batch_ptrs[batch_idx]][icon_instr_dispatch_ptr].receiver_list.receiver_str = 1'b0;
          icon_instr_dispatch[batch_idx][icon_batch_ptrs[batch_idx]][icon_instr_dispatch_ptr].receiver_list.receiver_mxreg = 1'b0;

          //NOTE: successful read is when read_result = total number of passed arguments to fscanf (after the file and fmt args)
          if (read_result != (3 + (NUM_EXEC_UNITS*2) + 1)) begin
            `uvm_fatal("BACKEND_TEST0", $sformatf("Failed to read icon instr at line %0d", line_idx))
          end

          icon_instr_dispatch_valid[batch_idx][icon_batch_ptrs[batch_idx]][icon_instr_dispatch_ptr] = 1'b1;

          icon_instr_dispatch_ptr = icon_instr_dispatch_ptr + 1;
        end

        4'b0100: begin
          string opcodeStr;
          `uvm_info("BACKEND_TEST0", "Reading instruction type: reg-none", UVM_MEDIUM)
          read_result = $fscanf(file, fmt_code_reg_none,
            instr_dispatch_alloc_euidx[batch_idx][instr_dispatch_ptr],
            opcodeStr,
            instr_dispatch[batch_idx][instr_dispatch_ptr].opd.euidx,
            instr_dispatch[batch_idx][instr_dispatch_ptr].opd.uid,
            instr_dispatch[batch_idx][instr_dispatch_ptr].opd.spec,
            instr_dispatch[batch_idx][instr_dispatch_ptr].op0.as_addr.euidx,
            instr_dispatch[batch_idx][instr_dispatch_ptr].op0.as_addr.uid,
            instr_dispatch[batch_idx][instr_dispatch_ptr].op0.as_addr.spec
          );
          if (read_result != 8) begin
            `uvm_fatal("BACKEND_TEST0", $sformatf("Failed to read reg-none instr at line %0d", line_idx))
          end

          //backend does not have an op1v flag (as its more or less embedded in the opcode)
          //so just add dummy immediate
          instr_dispatch[batch_idx][instr_dispatch_ptr].op1.as_imm.data = 'd0;
          instr_dispatch[batch_idx][instr_dispatch_ptr].op1m = IMM_OR_NONE;
          instr_dispatch[batch_idx][instr_dispatch_ptr].op0m = REG;
          instr_dispatch[batch_idx][instr_dispatch_ptr].opcode.specific_instr = conv_opc_str_to_enum(opcodeStr);
          instr_dispatch[batch_idx][instr_dispatch_ptr].opcode.exec_type = EXEC_UNIT;

          instr_dispatch_valid[batch_idx][instr_dispatch_ptr] = 1'b1;

          instr_dispatch_ptr = instr_dispatch_ptr + 1;
        end
        
        4'b0111: begin
          string opcodeStr;
          `uvm_info("BACKEND_TEST0", "Reading instruction type: reg-reg", UVM_MEDIUM)
          read_result = $fscanf(file, fmt_code_reg_reg,
            instr_dispatch_alloc_euidx[batch_idx][instr_dispatch_ptr],
            opcodeStr,
            instr_dispatch[batch_idx][instr_dispatch_ptr].opd.euidx,
            instr_dispatch[batch_idx][instr_dispatch_ptr].opd.uid,
            instr_dispatch[batch_idx][instr_dispatch_ptr].opd.spec,
            instr_dispatch[batch_idx][instr_dispatch_ptr].op0.as_addr.euidx,
            instr_dispatch[batch_idx][instr_dispatch_ptr].op0.as_addr.uid,
            instr_dispatch[batch_idx][instr_dispatch_ptr].op0.as_addr.spec,
            instr_dispatch[batch_idx][instr_dispatch_ptr].op1.as_addr.euidx,
            instr_dispatch[batch_idx][instr_dispatch_ptr].op1.as_addr.uid,
            instr_dispatch[batch_idx][instr_dispatch_ptr].op1.as_addr.spec
          );
          if (read_result != 11) begin
            `uvm_fatal("BACKEND_TEST0", $sformatf("Failed to read reg-reg instr at line %0d", line_idx))
          end

          instr_dispatch[batch_idx][instr_dispatch_ptr].op0m = REG;
          instr_dispatch[batch_idx][instr_dispatch_ptr].op1m = REG;
          instr_dispatch[batch_idx][instr_dispatch_ptr].opcode.specific_instr = conv_opc_str_to_enum(opcodeStr);
          instr_dispatch[batch_idx][instr_dispatch_ptr].opcode.exec_type = EXEC_UNIT;

          instr_dispatch_valid[batch_idx][instr_dispatch_ptr] = 1'b1;

          instr_dispatch_ptr = instr_dispatch_ptr + 1;
        end

        4'b0110: begin
          string opcodeStr;
          `uvm_info("BACKEND_TEST0", "Reading instruction type: reg-imm", UVM_MEDIUM)
          read_result = $fscanf(file, fmt_code_reg_imm,
            instr_dispatch_alloc_euidx[batch_idx][instr_dispatch_ptr],
            opcodeStr,
            instr_dispatch[batch_idx][instr_dispatch_ptr].opd.euidx,
            instr_dispatch[batch_idx][instr_dispatch_ptr].opd.uid,
            instr_dispatch[batch_idx][instr_dispatch_ptr].opd.spec,
            instr_dispatch[batch_idx][instr_dispatch_ptr].op0.as_addr.euidx,
            instr_dispatch[batch_idx][instr_dispatch_ptr].op0.as_addr.uid,
            instr_dispatch[batch_idx][instr_dispatch_ptr].op0.as_addr.spec,
            instr_dispatch[batch_idx][instr_dispatch_ptr].op1.as_imm
          );
          if (read_result != 9) begin
            `uvm_fatal("BACKEND_TEST0", $sformatf("Failed to read reg-imm instr at line %0d", line_idx))
          end
          `uvm_info("BACKEND_TEST0", $sformatf("addr.spec: %0d", instr_dispatch[batch_idx][instr_dispatch_ptr].opd.spec), UVM_MEDIUM)

          instr_dispatch[batch_idx][instr_dispatch_ptr].op0m = REG;
          instr_dispatch[batch_idx][instr_dispatch_ptr].op1m = IMM_OR_NONE;
          instr_dispatch[batch_idx][instr_dispatch_ptr].opcode.specific_instr = conv_opc_str_to_enum(opcodeStr);
          instr_dispatch[batch_idx][instr_dispatch_ptr].opcode.exec_type = EXEC_UNIT;

          instr_dispatch_valid[batch_idx][instr_dispatch_ptr] = 1'b1;

          instr_dispatch_ptr = instr_dispatch_ptr + 1;
        end

        4'b0000: begin
          string opcodeStr;
          `uvm_info("BACKEND_TEST0", "Reading instruction type: imm-none", UVM_MEDIUM)
          read_result = $fscanf(file, fmt_code_imm_none,
            instr_dispatch_alloc_euidx[batch_idx][instr_dispatch_ptr],
            opcodeStr,
            instr_dispatch[batch_idx][instr_dispatch_ptr].opd.euidx,
            instr_dispatch[batch_idx][instr_dispatch_ptr].opd.uid,
            instr_dispatch[batch_idx][instr_dispatch_ptr].opd.spec,
            instr_dispatch[batch_idx][instr_dispatch_ptr].op0.as_imm
          );
          if (read_result != 6) begin
            `uvm_fatal("BACKEND_TEST0", $sformatf("Failed to read imm-none instr at line %0d", line_idx))
          end

          //backend does not have an op1v flag (as its more or less embedded in the opcode)
          //so just add dummy immediate
          instr_dispatch[batch_idx][instr_dispatch_ptr].op1.as_imm.data = 'd0;
          instr_dispatch[batch_idx][instr_dispatch_ptr].op0m = IMM_OR_NONE;
          instr_dispatch[batch_idx][instr_dispatch_ptr].op1m = IMM_OR_NONE;
          instr_dispatch[batch_idx][instr_dispatch_ptr].opcode.specific_instr = conv_opc_str_to_enum(opcodeStr);
          instr_dispatch[batch_idx][instr_dispatch_ptr].opcode.exec_type = EXEC_UNIT;

          instr_dispatch_valid[batch_idx][instr_dispatch_ptr] = 1'b1;

          instr_dispatch_ptr = instr_dispatch_ptr + 1;
        end

        4'b0011: begin
          string opcodeStr;
          `uvm_info("BACKEND_TEST0", "Reading instruction type: imm-reg", UVM_MEDIUM)
          read_result = $fscanf(file, fmt_code_imm_reg,
            instr_dispatch_alloc_euidx[batch_idx][instr_dispatch_ptr],
            opcodeStr,
            instr_dispatch[batch_idx][instr_dispatch_ptr].opd.euidx,
            instr_dispatch[batch_idx][instr_dispatch_ptr].opd.uid,
            instr_dispatch[batch_idx][instr_dispatch_ptr].opd.spec,
            instr_dispatch[batch_idx][instr_dispatch_ptr].op0.as_imm,
            instr_dispatch[batch_idx][instr_dispatch_ptr].op1.as_addr.euidx,
            instr_dispatch[batch_idx][instr_dispatch_ptr].op1.as_addr.uid,
            instr_dispatch[batch_idx][instr_dispatch_ptr].op1.as_addr.spec
          );
          if (read_result != 9) begin
            `uvm_fatal("BACKEND_TEST0", $sformatf("Failed to read imm-reg instr at line %0d", line_idx))
          end

          instr_dispatch[batch_idx][instr_dispatch_ptr].op0m = IMM_OR_NONE;
          instr_dispatch[batch_idx][instr_dispatch_ptr].op1m = REG;
          instr_dispatch[batch_idx][instr_dispatch_ptr].opcode.specific_instr = conv_opc_str_to_enum(opcodeStr);
          instr_dispatch[batch_idx][instr_dispatch_ptr].opcode.exec_type = EXEC_UNIT;

          instr_dispatch_valid[batch_idx][instr_dispatch_ptr] = 1'b1;

          instr_dispatch_ptr = instr_dispatch_ptr + 1;
        end

        4'b0010: begin
          string opcodeStr;
          //enum_instr_exec_unit opcode_enum;
          `uvm_info("BACKEND_TEST0", "Reading instruction type: imm-imm", UVM_MEDIUM)
          read_result = $fscanf(file, fmt_code_imm_imm,
            instr_dispatch_alloc_euidx[batch_idx][instr_dispatch_ptr],
            opcodeStr,
            instr_dispatch[batch_idx][instr_dispatch_ptr].opd.euidx,
            instr_dispatch[batch_idx][instr_dispatch_ptr].opd.uid,
            instr_dispatch[batch_idx][instr_dispatch_ptr].opd.spec,
            instr_dispatch[batch_idx][instr_dispatch_ptr].op0.as_imm,
            instr_dispatch[batch_idx][instr_dispatch_ptr].op1.as_imm
          );
          if (read_result != 7) begin
            `uvm_fatal("BACKEND_TEST0", $sformatf("Failed to read imm-imm instr at line %0d", line_idx))
          end
          `uvm_info("BACKEND_TEST0", $sformatf("addr.spec: %0d", instr_dispatch[batch_idx][instr_dispatch_ptr].opd.spec), UVM_MEDIUM)

          instr_dispatch[batch_idx][instr_dispatch_ptr].op0m = IMM_OR_NONE;
          instr_dispatch[batch_idx][instr_dispatch_ptr].op1m = IMM_OR_NONE;
          
          instr_dispatch[batch_idx][instr_dispatch_ptr].opcode.specific_instr = conv_opc_str_to_enum(opcodeStr);
          instr_dispatch[batch_idx][instr_dispatch_ptr].opcode.exec_type = EXEC_UNIT;

          instr_dispatch_valid[batch_idx][instr_dispatch_ptr] = 1'b1;

          instr_dispatch_ptr = instr_dispatch_ptr + 1;
        end

        default: `uvm_fatal("BACKEND_TEST0", $sformatf("Unrecognised format code: %b", instruction_format))
      endcase

      //note that if num icon instructions held = num icon channels, only dispatch
      //icon instructions and not the normal one, if the batch is filled, both normal and icon
      //instructions should be dispatched
      if (instr_dispatch_ptr == NUM_PARALLEL_INSTR_DISPATCHES) begin
        `uvm_info("BACKEND_TEST0", "Batch filled. Moving to next batch idx", UVM_MEDIUM)
        batch_idx = batch_idx + 1;
        if(batch_idx == NUM_BATCHES) begin
          `uvm_fatal("BACKEND_TEST0", "NUM_BATCHES is too small")
        end
        
        instr_dispatch_ptr = 'd0;
        icon_instr_dispatch_ptr = 'd0;
      end else if (icon_instr_dispatch_ptr == NUM_ICON_CHANNELS) begin
        `uvm_info("BACKEND_TEST0", "icon batch filled. Moving to next icon batch idx within same batch", UVM_MEDIUM)
        icon_batch_ptrs[batch_idx] = icon_batch_ptrs[batch_idx] + 1;
        if(icon_batch_ptrs[batch_idx] == NUM_ICON_BATCHES) begin
          `uvm_fatal("BACKEND_TEST0", "NUM_ICON_BATCHES is too small")
        end
        
        icon_instr_dispatch_ptr = 'd0;
      end
      
      line_idx = line_idx + 1;
    end
    `uvm_info("BACKEND_TEST0", "Reached end of format file", UVM_MEDIUM)
    //`uvm_info("BACKEND_TEST0", $sformatf("%0d", $feof(file_instr_formats)), UVM_MEDIUM)

    // Close the files
    $fclose(file);
    $fclose(file_instr_formats);

    `uvm_info("BACKEND_TEST0", "Finished sequence construction", UVM_MEDIUM)
  endtask

  //Note that this algorithm also splits the batches into smaller batches
  //that can be passed in a single cycle to the required iqueues when they are ready
  //this is to avoid packets being dropped due to iqueues ignoring instructions when
  //more than EU_IQUEUE_NUM_QUEUES number of instructions are dispatched to the same EU
  virtual task body();
    backend_sequence_item seq_item;
    int v1, v2, v3;
    for (int i = 0; i < NUM_BATCHES; i++) begin
      `uvm_info("BACKEND_TEST0", "Dispatching icon mini batches (apart from last one)", UVM_MEDIUM)
      `uvm_info("BACKEND_TEST0", $sformatf("num icon batches in this batch[%0d]=%0d", i, icon_batch_ptrs[i]+1), UVM_MEDIUM)
      //note that icon_batch_ptrs[i] is one less the number of icon batches within the batch
      for (int j = 0; j < (icon_batch_ptrs[i]); j++) begin
        //dispatch all icon batches apart from last one which is dispatched
        //in same seq item as main batch
        seq_item = backend_sequence_item::type_id::create("seq_item");
        start_item(seq_item);
        seq_item.reset_n = 1'b1;
        for(int g_parallel_dist = 0; g_parallel_dist < NUM_PARALLEL_INSTR_DISPATCHES; g_parallel_dist++) begin
          seq_item.instr_dispatch_valid_i[g_parallel_dist] = 'b0;
        end
        seq_item.icon_instr_dispatch_i = icon_instr_dispatch[i][j];
        seq_item.icon_instr_dispatch_valid_i = icon_instr_dispatch_valid[i][j];
        finish_item(seq_item);
      end

      v1 = instr_dispatch_alloc_euidx[i][0];
      v2 = 1;
      v3 = 0;
      for (int k = 1; k < NUM_PARALLEL_INSTR_DISPATCHES; k++) begin
        `uvm_info("BACKEND_TEST0", $sformatf("v2=%0d k=%0d", v2, k), UVM_MEDIUM)
        if (instr_dispatch_valid[i][k]) begin
          `uvm_info("BACKEND_TEST0", $sformatf("v1=%0d, eu_alloc[k]=%0d", v1, instr_dispatch_alloc_euidx[i][k]), UVM_MEDIUM)
          if (v1 == instr_dispatch_alloc_euidx[i][k]) begin
            v2++;
          end else begin
            v1 = instr_dispatch_alloc_euidx[i][k];
            v2 = 0;
            //v3 = k;
          end
        end
        if( (v2 == EU_IQUEUE_NUM_QUEUES) | (k == (NUM_PARALLEL_INSTR_DISPATCHES-1)) ) begin
          //`uvm_info("BACKEND_TEST0", $sformatf("k=%0d", k), UVM_MEDIUM)
          `uvm_info("BACKEND_TEST0", $sformatf("Dispatching..."), UVM_MEDIUM)
          seq_item = backend_sequence_item::type_id::create("seq_item");
          start_item(seq_item);
          seq_item.reset_n = 1'b1;
          seq_item.instr_dispatch_i = instr_dispatch[i];
          seq_item.dispatched_instr_alloc_euidx_i = instr_dispatch_alloc_euidx[i];
          
          for(int k1 = 0; k1 < v3; k1++) begin
            seq_item.instr_dispatch_valid_i[k1] = 'b0;
          end
          for(int k1 = v3; k1 <= k; k1++) begin
            seq_item.instr_dispatch_valid_i[k1] = instr_dispatch_valid[i][k1];
          end
          for(int k1 = k+1; k1 < NUM_PARALLEL_INSTR_DISPATCHES; k1++) begin
            seq_item.instr_dispatch_valid_i[k1] = 'b0;
          end

          if (k == (NUM_PARALLEL_INSTR_DISPATCHES-1)) begin
            `uvm_info("BACKEND_TEST0", $sformatf("Dispatching icon instructions for batch..."), UVM_MEDIUM)
            seq_item.icon_instr_dispatch_i = icon_instr_dispatch[i][icon_batch_ptrs[i]];
            seq_item.icon_instr_dispatch_valid_i = icon_instr_dispatch_valid[i][icon_batch_ptrs[i]];
          end else begin
            `uvm_info("BACKEND_TEST0", $sformatf("Icon instructions will be dispatched in final micro batch"), UVM_MEDIUM)
            for (int k2 = 0; k2 < NUM_ICON_CHANNELS; k2++) begin
              seq_item.icon_instr_dispatch_i[k2] = 'b0;
              seq_item.icon_instr_dispatch_valid_i[k2] = 'b0;
            end
          end
          finish_item(seq_item);

          v2 = 0;
          v3 = k+1;
        end
      end

      /*seq_item = backend_sequence_item::type_id::create("seq_item");
      start_item(seq_item);
      seq_item.reset_n = 1'b1;
      seq_item.instr_dispatch_i = instr_dispatch[i];
      seq_item.instr_dispatch_valid_i = instr_dispatch_valid[i];
      seq_item.dispatched_instr_alloc_euidx_i = instr_dispatch_alloc_euidx[i];

      seq_item.icon_instr_dispatch_i = icon_instr_dispatch[i][icon_batch_ptrs[i]-1];
      seq_item.icon_instr_dispatch_valid_i = icon_instr_dispatch_valid[i][icon_batch_ptrs[i]-1];
      finish_item(seq_item);*/
    end

    //next steps do nothing
    //its just to delay the $finish call
    `uvm_info("BACKEND_TEST0", "Adding empty packets", UVM_MEDIUM)
    for (int step = 0; step < 50; step++) begin
      seq_item = backend_sequence_item::type_id::create("seq_item");
      start_item(seq_item);
      seq_item.reset_n = 1'b1;
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
