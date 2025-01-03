import uvm_pkg::*;
`include "uvm_macros.svh"

`include "seqItem_alpuWithCache.sv"

class alpuWithcache_sequencer #(
) extends uvm_sequencer #(alpuWithCache_sequence_item);

  //`uvm_component_param_utils(alpuWithCache_sequencer#( .REG_WIDTH(REG_WIDTH) ))
  `uvm_component_utils(alpuWithCache_sequencer)

  function new(string name = "alpuWithCache_sequencer", uvm_component parent = null);
    super.new(name, parent);
  endfunction
endclass

class alpuWithCache_driver #(
  parameter ADDR_WIDTH = 4,
  parameter DATA_WIDTH = 4
) extends uvm_driver #(alpuWithCache_sequence_item #( .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH) ));

  `uvm_component_param_utils(alpuWithCache_driver#( .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH) ))

  virtual intf_alpuWithCache #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
  ).DRIVER_SIDE vintf;
  
  function new(string name = "test_design_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    `uvm_info(get_full_name(), "Building...", UVM_LOW)
    super.build_phase(phase);
    if(!uvm_config_db#( virtual intf_alpuWithCache #( .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH)) )::get(this, "", "intf_alpuWithCache_driver_side", vintf)) begin
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

  virtual task drive(alpuWithCache_sequence_item #( .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH) ) seq_item);
    vintf.addr_i  <= seq_item.addr_i;
    vintf.wdata_i <= seq_item.wdata_i;
    vintf.ce_i    <= seq_item.ce_i;
    vintf.we_i    <= seq_item.we_i;
  endtask
endclass

class alpuWithCache_agent #(
  parameter ADDR_WIDTH = 4,
  parameter DATA_WIDTH = 4
) extends uvm_agent;

  `uvm_component_param_utils(alpuWithCache_agent#( .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH) ))

  alpuWithCache_driver #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
  ) driver;
  
  alpuWithCache_sequencer #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
  ) sequencer;

  function new(string name = "alpuWithCache_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    `uvm_info(get_full_name(), "Building...", UVM_LOW)

    driver    = alpuWithCache_driver    #( .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH) ) ::type_id::create("driver", this);
    sequencer = alpuWithCache_sequencer #( .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH) ) ::type_id::create("sequencer", this);
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    `uvm_info(get_full_name(), "Connecting...", UVM_LOW)
    driver.seq_item_port.connect(sequencer.seq_item_export);
  endfunction
endclass
