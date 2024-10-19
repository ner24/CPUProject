import uvm_pkg::*;
`include "uvm_macros.svh"

class alpu_cache_sequence_item #(
  parameter ADDR_WIDTH = 4,
  parameter DATA_WIDTH = 4
) extends uvm_sequence_item;

  `uvm_object_param_utils(alpu_cache_sequence_item#( .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH) ))

  rand logic  [ADDR_WIDTH-1:0] addr_i;
  rand logic  [DATA_WIDTH-1:0] wdata_i;

  logic                   ce_i;
  logic                   we_i;

  logic  [DATA_WIDTH-1:0] rdata_o;
  logic                   rvalid_o;
  logic                   wack_o;

  constraint cons {
  }

  function new(string name = "alpu_cache_sequence_item");
    super.new(name);
  endfunction

endclass

//leaving custom class even though not strictly necessary but might be useful
class alpu_cache_sequencer #(
  //parameter REG_WIDTH = 4
) extends uvm_sequencer #(alpu_cache_sequence_item /*#( .REG_WIDTH(REG_WIDTH))*/ );

  //`uvm_component_param_utils(alpu_cache_sequencer#( .REG_WIDTH(REG_WIDTH) ))
  `uvm_component_utils(alpu_cache_sequencer)

  // Tasks and Functions
  function new(string name = "alpu_cache_sequencer", uvm_component parent = null);
    super.new(name, parent);
  endfunction
endclass

class alpu_cache_driver #(
  parameter ADDR_WIDTH = 4,
  parameter DATA_WIDTH = 4
) extends uvm_driver #(alpu_cache_sequence_item #( .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH) ));

  `uvm_component_param_utils(alpu_cache_driver#( .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH) ))

  virtual intf_alpu_cache #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
  ).DRIVER_SIDE vintf;
  
  function new(string name = "test_design_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    `uvm_info(get_full_name(), "Building...", UVM_LOW)
    super.build_phase(phase);
    if(!uvm_config_db#( virtual intf_alpu_cache #( .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH)) )::get(this, "", "intf_alpu_cache_driver_side", vintf)) begin
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

  virtual task drive(alpu_cache_sequence_item #( .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH) ) seq_item);
    vintf.addr_i  <= seq_item.addr_i;
    vintf.wdata_i <= seq_item.wdata_i;
    vintf.ce_i    <= seq_item.ce_i;
    vintf.we_i    <= seq_item.we_i;
  endtask
endclass

class alpu_cache_monitor #(
  parameter ADDR_WIDTH = 4,
  parameter DATA_WIDTH = 4
) extends uvm_monitor;

  // Factory Registration
  `uvm_component_param_utils(alpu_cache_monitor#( .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH) ))

  // Variables

  virtual alu_dut_intf #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
  ) vintf;

  // Analysis Port
  uvm_analysis_port #(alpu_cache_sequence_item #( .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH) )) analysis_port;

  // Tasks and Functions

  function new(string name = "test_design_monitor", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    `uvm_info(get_full_name(), "Building...", UVM_LOW)
    if(!uvm_config_db#(virtual alu_dut_intf #( .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH) ))::get(this, "", "intf_alu", vintf)) begin
      `uvm_fatal(get_type_name(), " Couldn't get vintf, check uvm config for interface?")
    end
    analysis_port = new("alpu_cache_analysis_port", this);
  endfunction

  virtual task run_phase(uvm_phase phase);
    alpu_cache_sequence_item #(
      .ADDR_WIDTH(ADDR_WIDTH),
      .DATA_WIDTH(DATA_WIDTH)
    ) sequence_item;
    sequence_item = alpu_cache_sequence_item#( .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH) )::type_id::create("sequence_item");

    forever begin
      @(posedge vintf.clk);

      seq_item.addr_i   <= vintf.addr_i;
      seq_item.wdata_i  <= vintf.wdata_i;
      seq_item.ce_i     <= vintf.ce_i;
      seq_item.we_i     <= vintf.we_i;
      seq_item.rdata_o  <= vintf.rdata_o;
      seq_item.rvalid_o <= vintf.rvalid_o;
      seq_item.wack_o   <= vintf.wack_o;
      
      analysis_port.write(sequence_item);
      
      `uvm_info(get_full_name(), "Written Sequence Item from Monitor", UVM_DEBUG)
    end
  endtask
endclass

class alpu_cache_agent #(
  parameter ADDR_WIDTH = 4,
  parameter DATA_WIDTH = 4
) extends uvm_agent;

  `uvm_component_param_utils(alpu_cache_agent#( .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH) ))

  alpu_cache_driver #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
  ) driver;
  
  alpu_cache_sequencer #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
  ) sequencer;

  alpu_cache_monitor #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
  ) monitor;

  function new(string name = "alpu_cache_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    `uvm_info(get_full_name(), "Building...", UVM_LOW)

    driver    = alpu_cache_driver    #( .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH) ) ::type_id::create("driver", this);
    sequencer = alpu_cache_sequencer #( .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH) ) ::type_id::create("sequencer", this);
    monitor   = alpu_cache_monitor   #( .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH) ) ::type_id::create("monitor", this);
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    `uvm_info(get_full_name(), "Connecting...", UVM_LOW)
    driver.seq_item_port.connect(sequencer.seq_item_export);
  endfunction
endclass
