`define ALU_TB_TOP

`include "alu_tb_parameters.sv"
`include "tests/test_operations.sv"

module alu_tb import uvm_pkg::*; (
`ifndef ALU_TB_TOP
  input  wire clk
`endif
);

  localparam REG_WIDTH = `ALU_TB_REG_WIDTH;

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
  end

  alu #(
    .REG_WIDTH(REG_WIDTH)
  ) dut (
    .reset_n  (alu_intf.reset_n),
    .instr_i  (alu_intf.instr_i),
    .a_i      (alu_intf.a_i),
    .b_i      (alu_intf.b_i),
    .cin_i    (alu_intf.cin_i),
    .acc_o    (alu_intf.out_o),
    .cout_o   (alu_intf.cout_o)
  );

`ifdef ALU_TB_TOP
  //does some strange uvm thing which apparently registers the parameterised test
  //typedef test_operations#( .REG_WIDTH(REG_WIDTH) ) test_type;

  initial begin
    run_test("test_operations");
  end
`endif

endmodule


