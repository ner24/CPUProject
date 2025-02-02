import uvm_pkg::*;
`include "uvm_macros.svh"

`include "seqItem_alpu_cache.sv"

class eu_cache_sequencer #(
) extends uvm_sequencer #(eu_cache_sequencer);
  `uvm_component_utils(eu_cache_sequencer)

  function new(string name = "eu_cache_sequencer", uvm_component parent = null);
    super.new(name, parent);
  endfunction
endclass

class eu_cache_driver #(
) extends uvm_driver #( eu_cache_sequence_item #() );

  `uvm_component_param_utils(eu_cache_driver #())

  virtual intf_eu_cache #(
  ) vintf;
  
  function new(string name = "test_design_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    `uvm_info(get_full_name(), "Building...", UVM_LOW)
    super.build_phase(phase);
    if(!uvm_config_db#( virtual intf_eu_cache #() )::get(this, "", "intf_eu_cache", vintf)) begin
      `uvm_fatal(get_type_name(), "Could not find intf_eu_cache. Check interface in uvm config")
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

  virtual task drive( eu_cache_sequence_item #() seq_item);
    /*vintf.addr_i  <= seq_item.addr_i;
    vintf.wdata_i <= seq_item.wdata_i;
    vintf.ce_i    <= seq_item.ce_i;
    vintf.we_i    <= seq_item.we_i;*/
    //TODO: setup driver to run tests with eu cache as top
  endtask
endclass

class eu_cache_agent #(
) extends uvm_agent;

  `uvm_component_param_utils( eu_cache_agent #() )

  eu_cache_driver #() driver;
  
  eu_cache_sequencer #() sequencer;

  function new(string name = "alpu_cache_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    `uvm_info(get_full_name(), "Building...", UVM_LOW)

    driver    = eu_cache_driver    #() ::type_id::create("driver", this);
    sequencer = eu_cache_sequencer #() ::type_id::create("sequencer", this);
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    `uvm_info(get_full_name(), "Connecting...", UVM_LOW)
    driver.seq_item_port.connect(sequencer.seq_item_export);
  endfunction
endclass
