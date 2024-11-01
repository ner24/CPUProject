`include "uvm_macros.svh"
`include "alu_parameters.sv"
`include "simulation_parameters.sv"

`include "test_operations.sv" //to trigger compile

module alpu_tb_top import uvm_pkg::*; (
);
  localparam REG_WIDTH = `ALU_REG_WIDTH;

  logic clk;
  initial begin
    clk = 1'b0;
    forever begin
      #10 clk = ~clk;
    end
  end

  intf_alpu #(
    .REG_WIDTH(REG_WIDTH)
  ) intf (
    .clk(clk)
  );

  initial begin
    `uvm_info("alpu_tb_top", "Adding alpu top interface to uvm config", UVM_MEDIUM)
    //uvm_config_db_options::turn_on_tracing();
    uvm_config_db #( virtual intf_alpu #(.REG_WIDTH(REG_WIDTH)) )::set(null, "*", "intf_alpu_top", intf);
  end

  `SIM_TB_MODULE(alpu) #(
    .REG_WIDTH(REG_WIDTH),
    .USE_PIPELINED_ALPU(0)
  ) tb (
    .clk      (clk),
    .reset_n  (intf.reset_n),
    .instr_i  (intf.instr_i),
    .a_i      (intf.a_i),
    .b_i      (intf.b_i),
    .cin_i    (intf.cin_i),
    .out_o    (intf.out_o),
    .cout_o   (intf.cout_o)
  );

  initial begin
    run_test("test_operations");
  end
endmodule
