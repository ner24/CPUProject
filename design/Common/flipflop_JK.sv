module ff_jk #(
  
) (
  input  wire clk,

  input  wire j,
  input  wire k,
  output wire q
);

  wire q_n, q_int;
  wire j_1, k_1;

  assign j_1   = ~(q_n   & j & clk);
  assign k_1   = ~(q_int & k & clk);
  assign q_int = ~(j_1 & q_n  );
  assign q_n   = ~(k_1 & q_int);
  
  assign q = q_int;

endmodule
