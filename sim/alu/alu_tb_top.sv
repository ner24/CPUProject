`define ALU_TB_TOP

`include "alu_tb_parameters.sv"
`include "tests/test_operations.sv"

module alu_tb import uvm_pkg::*; (
`ifndef ALU_TB_TOP
  input  wire clk
`endif
);

  localparam REG_WIDTH = `ALU_TB_REG_WIDTH;
  localparam USE_PIPELINED_ALU = `ALU_TB_USE_PIPELINED_ALU;

`ifdef ALU_TB_TOP
  logic clk;

  initial begin
    clk = 0;
    forever begin
      #10 clk = ~clk;
    end
  end
`endif

  alu_dut_intf #(
    .REG_WIDTH(REG_WIDTH)
  ) alu_intf (
    .clk(clk)
  );

  initial begin
    uvm_config_db #( virtual alu_dut_intf #(.REG_WIDTH(REG_WIDTH)) )::set(null, "*", "intf_alu", alu_intf);
    uvm_config_db #( virtual alu_dut_intf #(.REG_WIDTH(REG_WIDTH)) .DRIVER_SIDE )::set(null, "*", "intf_alu_driver_side", alu_intf);
  end

  alu #(
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

  //SVAs
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

`ifdef ALU_TB_TOP
  initial begin
    run_test("test_operations");
  end
`endif

endmodule


