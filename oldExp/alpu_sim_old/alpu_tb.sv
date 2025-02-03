import uvm_pkg::*;
`include "uvm_macros.svh"

`include "alu_parameters.sv"
`include "simulation_parameters.sv"

`include "seqItem_alpu.sv"

typedef class alpu_monitor;

module `SIM_TB_MODULE(alpu) import uvm_pkg::*; #(
  parameter REG_WIDTH = 4,
  parameter USE_PIPELINED_ALPU = 0
) (
  input  wire                   clk,
  input  wire                   reset_n,

  input  logic            [3:0] instr_i,
  input  wire   [REG_WIDTH-1:0] a_i,
  input  wire   [REG_WIDTH-1:0] b_i,
  input  wire                   cin_i,
  output wire   [REG_WIDTH-1:0] out_o,
  output wire                   cout_o
);

  alpu #(
    .REG_WIDTH(REG_WIDTH),
    .USE_PIPELINED_ALPU(USE_PIPELINED_ALPU)
  ) dut (
    .clk      (clk),
    .reset_n  (reset_n),
    .instr_i  (instr_i),
    .a_i      (a_i),
    .b_i      (b_i),
    .cin_i    (cin_i),
    .out_o    (out_o),
    .cout_o   (cout_o)
  );

  intf_alpu #(
    .REG_WIDTH(REG_WIDTH)
  ) intf (
    .clk(clk)
  );
  assign intf.reset_n = reset_n;
  assign intf.instr_i = instr_i;
  assign intf.a_i     = a_i;
  assign intf.b_i     = b_i;
  assign intf.cin_i   = cin_i;
  assign intf.out_o   = out_o;
  assign intf.cout_o  = cout_o;

  initial begin
    uvm_config_db #( virtual intf_alpu #(.REG_WIDTH(REG_WIDTH)) )::set(null, "*", "intf_alpu", intf);
  end

  // --------------------
  // VERIF
  // --------------------
  alpu_monitor#( .REG_WIDTH(REG_WIDTH) ) verif_monitor;
  initial begin
    verif_monitor = alpu_monitor#( .REG_WIDTH(REG_WIDTH) )::type_id::create("monitor_alpu", null);
  end

  sva_alu_op #(
    .REG_WIDTH(REG_WIDTH),
    .USE_PIPELINED_ALPU(USE_PIPELINED_ALPU)
  ) u_sva_alu_op (
    .alu_clk    (clk),
    .alu_resetn (intf.reset_n),
    .alu_cir    (intf.instr_i),
    .in_a       (intf.a_i),
    .in_b       (intf.b_i),
    .out        (intf.out_o)
  );

endmodule

class alpu_monitor #(
  parameter REG_WIDTH = 4
) extends uvm_monitor;

  `uvm_component_param_utils(alpu_monitor#( .REG_WIDTH(REG_WIDTH) ))

  virtual intf_alpu #(
    .REG_WIDTH(REG_WIDTH)
  ) vintf;

  uvm_analysis_port #(alpu_sequence_item #( .REG_WIDTH(REG_WIDTH) )) analysis_port;

  function new(string name = "test_design_monitor", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  virtual function void build_phase(uvm_phase phase);
    `uvm_info(get_full_name(), "Building...", UVM_LOW)
    if(!uvm_config_db#(virtual intf_alpu #( .REG_WIDTH(REG_WIDTH) ))::get(this, "", "intf_alpu", vintf)) begin
      `uvm_fatal(get_type_name(), " Couldn't get vintf, check uvm config for interface?")
    end
    analysis_port = new("alpu_analysis_port", this);
  endfunction

  virtual task run_phase(uvm_phase phase);
    alpu_sequence_item #(
      .REG_WIDTH(REG_WIDTH)
    ) sequence_item;
    sequence_item = alpu_sequence_item#( .REG_WIDTH(REG_WIDTH) )::type_id::create("sequence_item");

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
