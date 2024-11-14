module tri_state_test #(
  parameter DATA_WIDTH = 1,
  parameter NUM_TRI_STATES = 40
) (
  input  wire                   enable [NUM_TRI_STATES-1:0],
  input  wire  [DATA_WIDTH-1:0] din,
  output logic [DATA_WIDTH-1:0] dout [NUM_TRI_STATES-1:0]
);
  //wire [DATA_WIDTH-1:0] dout_int [NUM_TRI_STATES-1:0];
  generate for (genvar i = 0; i < NUM_TRI_STATES; i++) begin
    assign dout[i] = enable[i] ? din : 'z;
  end endgenerate

  /*always_comb begin
    dout = {DATA_WIDTH{1'b0}};
    for(int i = 0; i < NUM_TRI_STATES; i++) begin
      dout |= dout_int[i];
    end
  end*/
  //assign dout = |dout_int;

endmodule
