`include "uvm_macros.svh"
`include "design_parameters.sv"
`include "simulation_parameters.sv"

//tests have to be included to trigger compile
//so uvm can find them
`include "test_operations.sv"

module alu_tb_top import uvm_pkg::*; (
);
  logic clk;
  initial begin
    clk = 1'b0;
    forever begin
      #1 clk = ~clk;
    end
  end

  intf_alu intf (
    .clk(clk)
  );

  initial begin
    uvm_config_db #( virtual intf_alu )::set(null, "*", "intf_alu_top", intf);
  end

  `SIM_TB_MODULE(alu) #(
    .USE_PIPELINED_ALU(`ALU_USE_PIPELINED_ALU),
    .DATA_WIDTH(`WORD_WIDTH)
  ) tb (
    .clk(intf.clk),
    .reset_n(intf.reset_n),
    
    .alu_rx_i(intf.alu_rx_i),
    .alu_tx_o(intf.alu_tx_o),

    .curr_instr_i(intf.curr_instr_i),
    .curr_instr_valid_i(intf.curr_instr_valid_i),

    .ready_for_next_instr_o(intf.ready_for_next_instr_o)
  );

  initial begin
    run_test("test_operations");
  end
endmodule
