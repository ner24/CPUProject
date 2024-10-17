import uvm_pkg::*;
`include "uvm_macros.svh"

`include "projectConfig/alu_parameters.sv"
`include "projectConfig/simulation_parameters.sv"

`define MODULE_NAME alu_alpu_`VERIF_MODULE_SUFFIX_CONST
module `MODULE_NAME import uvm_pkg::*; (
  input  wire clk
);
  localparam REG_WIDTH = `ALU_REG_WIDTH;
  localparam USE_PIPELINED_ALU = `ALU_USE_PIPELINED_ALU;

  intf_alpu #(
    .REG_WIDTH(REG_WIDTH)
  ) alu_intf (
    .clk(clk)
  );

  initial begin
    uvm_config_db #( virtual intf_alpu #(.REG_WIDTH(REG_WIDTH)) )::set(null, "*", "intf_alu", alu_intf);
    uvm_config_db #( virtual intf_alpu #(.REG_WIDTH(REG_WIDTH)) .DRIVER_SIDE )::set(null, "*", "intf_alu_driver_side", alu_intf);
  end

  alu_alpu #(
    .REG_WIDTH(REG_WIDTH),
    .USE_PIPELINED_ALU(USE_PIPELINED_ALU)
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
  sva_alu_op #(
    .REG_WIDTH(REG_WIDTH),
    .USE_PIPELINED_ALU(USE_PIPELINED_ALU)
  ) u_sva_alu_op (
    .alu_clk    (clk),
    .alu_resetn (alu_intf.reset_n),
    .alu_cir    (alu_intf.instr_i),
    .in_a       (alu_intf.a_i),
    .in_b       (alu_intf.b_i),
    .out        (alu_intf.out_o)
  );

endmodule


