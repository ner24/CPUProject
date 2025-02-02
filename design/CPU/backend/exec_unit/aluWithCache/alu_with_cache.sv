`include "simulation_parameters.sv"

module alpu_with_cache import exec_unit_dtypes::*; #( //WIP. THis module without the IQueue only exists for verif purposes
  parameter EU_IDX = 0
) (
  input  wire                   clk,
  input  wire                   reset_n,

  //interconnect
  inout  wire type_icon_channel interconnect_port,

  //iqueue
  input  wire type_iqueue_entry ireq_curr_instr
);

  //interconnect interface

  `SIM_TB_MODULE(alu) #(
  ) alu (
    .clk(clk),
    .reset_n(reset_n),
    .instr_i(),
    .a_i(),
    .b_i(),
    .cin_i(),
    .out_o(),
    .cout_o()
  );

  `SIM_TB_MODULE(eu_cache) #(
    .EU_IDX(EU_IDX)
  ) cache (
    .clk      (clk),
    .reset_n  (reset_n)
    
  );

endmodule
