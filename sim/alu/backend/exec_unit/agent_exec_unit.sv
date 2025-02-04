import uvm_pkg::*;
`include "uvm_macros.svh"

`include "seqItem_exec_unit.sv"

class execution_unit_sequencer extends uvm_sequencer #(execution_unit_sequence_item);
  `uvm_component_utils(execution_unit_sequencer)

  function new(string name = "execution_unit_sequencer", uvm_component parent = null);
    super.new(name, parent);
  endfunction
endclass

class execution_unit_driver extends uvm_driver #(execution_unit_sequence_item);

  `uvm_component_utils(execution_unit_driver)

  virtual intf_eu vintf;
  
  function new(string name = "test_design_driver", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    `uvm_info(get_full_name(), "Building...", UVM_LOW)
    super.build_phase(phase);
    if(!uvm_config_db#( virtual intf_eu )::get(this, "", "intf_eu_top", vintf)) begin
      `uvm_fatal(get_type_name(), "Could not find specified alu interface. Check interface in uvm config")
    end
  endfunction
  
  virtual task reset_phase(uvm_phase phase);
    @(posedge vintf.clk);
    vintf.reset_n = 1'b1;
  endtask

  virtual task run_phase(uvm_phase phase);
    forever begin
      @(posedge vintf.clk);
      seq_item_port.get_next_item(req);
      drive(req);
      seq_item_port.item_done();
    end
  endtask

  virtual task drive(execution_unit_sequence_item seq_item);
    vintf.icon_rx0_i      <= seq_item.icon_rx0_i;
    vintf.icon_rx0_resp_o <= seq_item.icon_rx0_resp_o;
    vintf.icon_rx1_i      <= seq_item.icon_rx1_i;
    vintf.icon_rx1_resp_o <= seq_item.icon_rx1_resp_o;
    
    vintf.icon_tx_data_o      <= seq_item.icon_tx_data_o;
    vintf.icon_tx_addr_i      <= seq_item.icon_tx_addr_i;
    vintf.icon_tx_req_valid_i <= seq_item.icon_tx_req_valid_i;
    vintf.icon_tx_success_o   <= seq_item.icon_tx_success_o;

    vintf.dispatched_instr_i       <= seq_item.dispatched_instr_i;
    vintf.dispatched_instr_valid_i <= seq_item.dispatched_instr_valid_i;
    vintf.ready_for_next_instr_o   <= seq_item.ready_for_next_instr_o;
  endtask
endclass

class execution_unit_agent extends uvm_agent;

  `uvm_component_utils(execution_unit_agent)

  execution_unit_driver driver;
  
  execution_unit_sequencer sequencer;

  function new(string name = "execution_unit_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    `uvm_info(get_full_name(), "Building...", UVM_LOW)

    driver = execution_unit_driver::type_id::create("driver", this);
    sequencer = execution_unit_sequencer::type_id::create("sequencer", this);
  endfunction

  virtual function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    `uvm_info(get_full_name(), "Connecting...", UVM_LOW)
    driver.seq_item_port.connect(sequencer.seq_item_export);
  endfunction
endclass
