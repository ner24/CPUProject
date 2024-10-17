`include "projectConfig/alu_parameters.sv"
`include "projectConfig/simulation_parameters.sv"
`include "test_operations.sv"

module alu_alpu_tb_top import uvm_pkg::*; (
);
  logic clk;
  initial begin
    clk = 1'b0;
    forever begin
      #10 clk = ~clk;
    end
  end

  alu_alpu_`VERIF_MODULE_SUFFIX #(
  ) dut (
    .clk(clk)
  );

  initial begin
    run_test("test_operations");
  end
endmodule
