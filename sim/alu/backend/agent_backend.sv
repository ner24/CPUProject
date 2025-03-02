import uvm_pkg::*;
`include "uvm_macros.svh"

`include "seqItem_backend.sv"
`include "design_parameters.sv"

class backend_sequencer extends uvm_sequencer #(backend_sequence_item);
  `uvm_component_utils(backend_sequencer)

  function new(string name = "backend_sequencer", uvm_component parent = null);
    super.new(name, parent);
  endfunction
endclass

class backend_driver extends uvm_driver #(backend_sequence_item);

  `uvm_component_utils(backend_driver)

  virtual intf_backend vintf;
  
  function new(string name = "test_design_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    `uvm_info(get_full_name(), "Building...", UVM_LOW)
    super.build_phase(phase);
    if(!uvm_config_db#( virtual intf_backend )::get(this, "", "intf_backend_top", vintf)) begin
      `uvm_fatal(get_type_name(), "Could not find specified backend interface. Check interface in uvm config")
    end
  endfunction
  
  virtual task reset_phase(uvm_phase phase);
    vintf.reset_n = 1'b0;
    @(posedge vintf.clk);
    vintf.reset_n = 1'b1;
  endtask

  virtual task run_phase(uvm_phase phase);
    forever begin
      seq_item_port.get_next_item(req);

      //only switch to next item when backend is ready
      //and all instructions within batch have been accepted
      
      @(posedge vintf.clk & vintf.instr_dispatch_ready_o & vintf.icon_instr_dispatch_ready_all_o);
      drive(req);
      seq_item_port.item_done();
    end
  endtask

  virtual task drive(backend_sequence_item seq_item);
    vintf.reset_n                     = seq_item.reset_n;
    vintf.instr_dispatch_i            = seq_item.instr_dispatch_i;
    vintf.instr_dispatch_valid_i      = seq_item.instr_dispatch_valid_i;
    vintf.dispatched_instr_alloc_euidx_i = seq_item.dispatched_instr_alloc_euidx_i;
    //vintf.instr_dispatch_ready_o      = seq_item.instr_dispatch_ready_o;
    vintf.icon_instr_dispatch_i       = seq_item.icon_instr_dispatch_i;
    vintf.icon_instr_dispatch_valid_i = seq_item.icon_instr_dispatch_valid_i;
    //vintf.icon_instr_dispatch_ready_o = seq_item.icon_instr_dispatch_ready_o;
  endtask
endclass

class backend_agent extends uvm_agent;

  `uvm_component_utils(backend_agent)

  backend_driver driver;
  
  backend_sequencer sequencer;

  function new(string name = "backend_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    `uvm_info(get_full_name(), "Building...", UVM_LOW)

    driver = backend_driver::type_id::create("driver", this);
    sequencer = backend_sequencer::type_id::create("sequencer", this);
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    `uvm_info(get_full_name(), "Connecting...", UVM_LOW)
    driver.seq_item_port.connect(sequencer.seq_item_export);
  endfunction
endclass
