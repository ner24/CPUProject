import uvm_pkg::*;
`include "uvm_macros.svh"

class alu_alpu_sequence_item #(
  parameter REG_WIDTH = 4
) extends uvm_sequence_item;

  `uvm_object_param_utils(alu_alpu_sequence_item#( .REG_WIDTH(REG_WIDTH) ))

  rand  logic [REG_WIDTH-1:0] a;
  rand  logic [REG_WIDTH-1:0] b;
        logic           [3:0] instr;
        logic   [REG_WIDTH:0] out; //1 longer than reg width to include cout

  constraint operandRange {
    a inside{[0:100]};
    b inside{[0:100]};
    //instr inside {4'd4};
  }

  function new(string name = "alu_alpu_sequence_item");
    super.new(name);
  endfunction

endclass

//leaving custom class even though not strictly necessary but might be useful
class alu_alpu_sequencer #(
  parameter REG_WIDTH = 4
) extends uvm_sequencer #(alu_alpu_sequence_item #( .REG_WIDTH(REG_WIDTH)) );

  `uvm_component_param_utils(alu_alpu_sequencer#( .REG_WIDTH(REG_WIDTH) ))

  // Tasks and Functions
  function new(string name = "alu_alpu_sequencer", uvm_component parent = null);
    super.new(name, parent);
  endfunction
endclass

class alu_alpu_driver #(
  parameter REG_WIDTH = 4
) extends uvm_driver #(alu_alpu_sequence_item #( .REG_WIDTH(REG_WIDTH) ));

  `uvm_component_param_utils(alu_alpu_driver#( .REG_WIDTH(REG_WIDTH) ))

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

  virtual task drive(alu_alpu_sequence_item #( .REG_WIDTH(REG_WIDTH) ) seq_item);
    vintf.a_i     <= seq_item.a;
    vintf.b_i     <= seq_item.b;
    vintf.instr_i <= seq_item.instr;
    vintf.cin_i   <= '0;
  endtask
endclass

class alu_alpu_monitor #(
    parameter REG_WIDTH = 4
) extends uvm_monitor;

  // Factory Registration
  `uvm_component_param_utils(alu_alpu_monitor#( .REG_WIDTH(REG_WIDTH) ))

  // Variables
  alu_alpu_sequence_item #(
    .REG_WIDTH(REG_WIDTH)
  ) sequence_item;

  virtual alu_dut_intf #(
    .REG_WIDTH(REG_WIDTH)
  ) vintf;

  // Analysis Port
  uvm_analysis_port #(alu_alpu_sequence_item #( .REG_WIDTH(REG_WIDTH) )) analysis_port;

  // Tasks and Functions

  function new(string name = "test_design_monitor", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    `uvm_info(get_full_name(), "Building...", UVM_LOW)
    if(!uvm_config_db#(virtual alu_dut_intf #( .REG_WIDTH(REG_WIDTH) ))::get(this, "", "intf_alu", vintf)) begin
      `uvm_fatal(get_type_name(), " Couldn't get vintf, check uvm config for interface?")
    end
    analysis_port = new("alu_alpu_analysis_port", this);
  endfunction

  virtual task run_phase(uvm_phase phase);
    alu_alpu_sequence_item #(
      .REG_WIDTH(REG_WIDTH)
    ) sequence_item;
    sequence_item = alu_alpu_sequence_item#( .REG_WIDTH(REG_WIDTH) )::type_id::create("sequence_item");

    forever begin
      @(posedge vintf.clk);

      sequence_item.a     = vintf.a_i;
      sequence_item.b     = vintf.b_i;
      sequence_item.instr = vintf.instr_i;
      sequence_item.out   = vintf.out_o;
      
      analysis_port.write(sequence_item);
      
      `uvm_info(get_full_name(), "Written Sequence Item from Monitor", UVM_DEBUG)
    end
  endtask
endclass

class alu_alpu_agent #(
  parameter REG_WIDTH = 4
) extends uvm_agent;

  `uvm_component_param_utils(alu_alpu_agent#( .REG_WIDTH(REG_WIDTH) ))

  //alu_alpu_agent_cfg agnt_cfg;

  alu_alpu_driver #(
    .REG_WIDTH(REG_WIDTH)
  ) driver;
  
  alu_alpu_sequencer #(
    .REG_WIDTH(REG_WIDTH)
  ) sequencer;

  alu_alpu_monitor #(
    .REG_WIDTH(REG_WIDTH)
  ) monitor;

  function new(string name = "alu_alpu_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    `uvm_info(get_full_name(), "Building...", UVM_LOW)

    driver    = alu_alpu_driver    #( .REG_WIDTH(REG_WIDTH) ) ::type_id::create("driver", this);
    sequencer = alu_alpu_sequencer #( .REG_WIDTH(REG_WIDTH) ) ::type_id::create("sequencer", this);
    monitor   = alu_alpu_monitor   #( .REG_WIDTH(REG_WIDTH) ) ::type_id::create("monitor", this);
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    `uvm_info(get_full_name(), "Connecting...", UVM_LOW)
    driver.seq_item_port.connect(sequencer.seq_item_export);
  endfunction
endclass