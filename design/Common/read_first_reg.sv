module reg_RF #(
  //stores all addresses as packed and uses address as mask.
  //designed for 1 or 2 bit values which would be space inefficient
  //to have individual storage cells for
  parameter ADDR_WIDTH = 2,
  parameter DATA_WIDTH = 1
) (
  input  wire                   clk,
  input  wire                   reset_n,

  input  wire  [ADDR_WIDTH-1:0] waddr_i,
  input  wire  [ADDR_WIDTH-1:0] raddr_i,

  input  wire  [DATA_WIDTH-1:0] wdata_i,
  input  wire                   we_i,

  output logic [DATA_WIDTH-1:0] rdata_o
);

  logic [ADDR_WIDTH-1:0] [DATA_WIDTH-1:0] r;

  logic [ADDR_WIDTH-1:0] [DATA_WIDTH-1:0] rmask;
  logic [ADDR_WIDTH-1:0] [DATA_WIDTH-1:0] wmask;
  always_comb begin
    rmask[raddr_i] = {DATA_WIDTH{1'b1}};
    wmask[waddr_i] = {DATA_WIDTH{1'b1}};
  end

  always_ff @(posedge clk) begin
    if (~reset_n) begin
      r = '0;
    end else begin
      rdata_o = r & rmask;
      if (we_i) begin
        r = wdata_i & wmask;
      end
    end
  end

endmodule
