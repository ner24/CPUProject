module comparator_3Input #( //3 way comparator but select only 1 bit
  parameter DATA_WIDTH = 2,
  parameter GREATER_OR_LESS = 0 //0 = greater, 1 = less
) (
  input  wire  [DATA_WIDTH-1:0] values [2:0],
  output wire                   select //is high when values[0] is either min or max (depending on GREATER_OR_LESS)
);

  wire [1:0] comp;
  generate for(genvar i = 1; i < 3; i++) begin: g_comp
    assign comp[i-1] = GREATER_OR_LESS ? values[0] < values[i] : values[0] > values[i];
  end endgenerate
  assign select = &comp;
endmodule
