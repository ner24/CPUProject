
module cpu #(
  parameter REG_WIDTH = 16
) (
  input  logic clk
);

  logic [REG_WIDTH-1:0] r1;
  logic [REG_WIDTH-1:0] r2;
  logic [REG_WIDTH-1:0] r3;
  logic [REG_WIDTH-1:0] f1;

  alu #(
    .REG_WIDTH(REG_WIDTH)
  ) u_alu (
    .instr_i  (f1[2 +: 4]),
    .a_i      (r1),
    .b_i      (r2),
    .cin_i    (f1[1]),
    .acc_o    (r3),
    .cout_o   (f1[0])
  );

endmodule : cpu
