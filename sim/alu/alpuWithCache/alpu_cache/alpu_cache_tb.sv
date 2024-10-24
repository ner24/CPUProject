import uvm_pkg::*;
`include "uvm_macros.svh"

`include "projectConfig/alu_parameters.sv"
`include "projectConfig/simulation_parameters.sv"
`include "seqItem_alpu_cache.sv"

typedef class alpu_cache_monitor;

module `SIM_TB_MODULE(alpu_cache) import uvm_pkg::*; #(
  parameter ADDR_WIDTH = 4,
  parameter DATA_WIDTH = 4
) (
  input  wire                   clk,
  input  wire                   reset_n,

  input  wire  [ADDR_WIDTH-1:0] addr_i,
  input  wire  [DATA_WIDTH-1:0] wdata_i,

  input  wire                   ce_i,
  input  wire                   we_i,

  output wire  [DATA_WIDTH-1:0] rdata_o,
  output wire                   rvalid_o,
  output wire                   wack_o
);
  
  intf_alpu_cache #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
  ) intf (
    .clk(clk)
  );
  assign intf.reset_n = reset_n;
  assign intf.addr_i  = addr_i;
  assign intf.wdata_i = wdata_i;
  assign intf.ce_i    = ce_i;
  assign intf.we_i    = we_i;
  assign intf.rdata_o = rdata_o;
  assign intf.rvalid_o= rvalid_o;
  assign intf.wack_o  = wack_o;


  initial begin
    uvm_config_db #( virtual intf_alpu_cache #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH)) )::set(null, "*", "intf_alpu_cache", intf);
  end

  alpu_cache #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
  ) dut (
    .clk      (clk),
    .reset_n  (reset_n),
    .addr_i   (addr_i),
    .wdata_i  (wdata_i),
    .ce_i     (ce_i),
    .we_i     (we_i),
    .rdata_o  (rdata_o),
    .rvalid_o (rvalid_o),
    .wack_o   (wack_o)
  );

  // --------------------
  // VERIF
  // --------------------
  alpu_cache_monitor#( .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH) ) verif_monitor;
  initial begin
    verif_monitor = alpu_cache_monitor#( .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH) )::type_id::create("monitor_alpu_cache", null);
  end

  //TODO: write asserts

endmodule

class alpu_cache_monitor #(
  parameter ADDR_WIDTH = 4,
  parameter DATA_WIDTH = 4
) extends uvm_monitor;
  `uvm_component_param_utils(alpu_cache_monitor#( .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH) ))

  virtual intf_alpu_cache #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
  ) vintf;

  uvm_analysis_port #(alpu_cache_sequence_item #( .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH) )) analysis_port;

  function new(string name = "test_design_monitor", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    `uvm_info(get_full_name(), "Building...", UVM_LOW)
    if(!uvm_config_db#(virtual intf_alpu_cache #( .ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH) ))::get(this, "", "intf_alpu_cache", vintf)) begin
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
    end
  endtask
endclass
