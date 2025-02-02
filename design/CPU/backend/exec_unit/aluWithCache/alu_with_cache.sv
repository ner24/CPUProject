`include "simulation_parameters.sv"

module alpu_with_cache import exec_unit_dtypes::*; #( //WIP. THis module without the IQueue only exists for verif purposes
  parameter REG_WIDTH = 4,
  parameter OPERAND_WIDTH = 4
) (
  input  wire                   clk,
  input  wire                   reset_n,

  //interconnect
  inout  wire type_icon_channel interconnect_port,

  //iqueue
  input  wire type_iqueue_entry ireq_curr_instr
);

  //interconnect interface

  `SIM_TB_MODULE(alpu) #(
    .REG_WIDTH(REG_WIDTH)
  ) alpu (
    .clk(clk),
    .reset_n(reset_n),
    .instr_i(),
    .a_i(),
    .b_i(),
    .cin_i(),
    .out_o(),
    .cout_o()
  );

  `SIM_TB_MODULE(alpu_cache) #(
    .ADDR_WIDTH(2), //for 4 entries
    .DATA_WIDTH(REG_WIDTH)
  ) cache (
    .clk      (clk),
    .reset_n  (reset_n)
    
  );

endmodule
