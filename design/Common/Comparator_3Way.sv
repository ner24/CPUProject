module comparator_3Input #(
  parameter DATA_WIDTH = 2,
  parameter GREATER_OR_LESS = 0 //0 = greater, 1 = less
) (
  //input  wire clk,
  //input  wire reset_n,

  input  wire  [DATA_WIDTH-1:0] values [2:0],

  output logic [2:0] select
);

  always_comb begin: comparator
    for (int i = 0; i < 3; i++) begin
      logic [2-1:0] sel_temp;
      logic[1:0] idx;
      idx = 2'd0;
      sel_temp = {2{1'b0}};
      for (int j = 0; j < 3; j++) begin
        if (~(j == i)) begin
          sel_temp[idx] = GREATER_OR_LESS ?
                          values[idx] > values[j]:
                          values[idx] < values[j];
          idx++;
        end
      end
      select[i] = &sel_temp;
    end
  end

endmodule

module comparator #(
  parameter DATA_WIDTH = 2,
  parameter GREATER_OR_LESS = 0 //0 = greater, 1 = less
) (
  input  wire  [DATA_WIDTH-1:0] values [1:0],

  output logic result
);

  always_comb begin: compare
    logic [DATA_WIDTH:0] temp [1:0];
    temp[0][DATA_WIDTH] = 1'b0;
    temp[1][DATA_WIDTH] = 1'b0;
    for(int i = DATA_WIDTH-1; i >= 0; i--) begin
      temp[0][i] = temp[i+1] | ( values[0][i] & ~values[1][i]);
      temp[1][i] = temp[i+1] | (~values[0][i] &  values[1][i]);

      /*temp[i] = ~(values[0][i] ^ values[1][i]) ?
                temp[i+1] : 
                (GREATER_OR_LESS ?
                  values[0][i] & ~values[1][i] :
                  ~values[0][i] &  values[1][i]);*/
    end
    result = GREATER_OR_LESS ? temp[1][0] & ~temp[0][0] : ~temp[1][0] & temp[0][0];
  end

endmodule
