import uvm_pkg::*;
`include "uvm_macros.svh"

`include "projectConfig/alu_parameters.sv"
`include "projectConfig/simulation_parameters.sv"

`define MODULE_NAME alpu_cache`VERIF_MODULE_SUFFIX_CONST
module `MODULE_NAME import uvm_pkg::*; #(
  parameter ADDR_WIDTH = 4,
  parameter DATA_WIDTH = 4
) (
  input  wire clk
);
  
  intf_alpu_cache #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
  ) intf (
    .clk(clk)
  );

  initial begin
    uvm_config_db #( virtual intf_alpu_cache #(.ADDR_WIDTH(ADDR_WIDTH), .DATA_WIDTH(DATA_WIDTH)) )::set(null, "*", "alpu_cache_intf", intf);
  end

  alpu_cache #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
  ) dut (
    .clk      (clk),
    .reset_n  (alu_intf.reset_n),
    .instr_i  (alu_intf.instr_i),
    .a_i      (alu_intf.a_i),
    .b_i      (alu_intf.b_i),
    .cin_i    (alu_intf.cin_i),
    .acc_o    (alu_intf.out_o),
    .cout_o   (alu_intf.cout_o)
  );

  // --------------------
  // Assertions
  // --------------------
  

endmodule
