module alpu_cache #(
  parameter DATA_WIDTH = 16,
  parameter ADDR_WIDTH = 8
) (
  input  wire                   clk,
  input  wire                   reset_n,

  input  wire  [ADDR_WIDTH-1:0] addr_i,
  input  wire  [DATA_WIDTH-1:0] wdata_i,

  input  wire                   ce_i,
  input  wire                   we_i,

  output wire  [DATA_WIDTH-1:0] rdata_o,
  //if tag address does not match on read, then read is invalid
  output wire                   rvalid_o,
  //if address writing to has not already been read, then write has not been acknowledged
  output wire                   wack_o
);
  
  wire [1:0] we;
  logic rw_swap;
  always_ff @(posedge clk or negedge reset_n) begin
    if(~reset_n) begin
      rw_swap <= '0;
    end else begin
      rw_swap = ~rw_swap;
    end
  end
  assign we[0] = rw_swap;
  assign we[1] = ~rw_swap;

  wire [1:0] [DATA_WIDTH-1:0] rdata_internal;
  wire                        rdata_c;
  wire                  [1:0] rvalid_internal;
  wire                  [1:0] wack_internal;
  assign rdata_c  = |rdata_internal;
  assign wack_o   = |wack_internal;
  generate for (genvar i = 0; i < 2; i++) begin: g_cache
    cache_MRP #(
      .IDX_BITS(2),
      .DATA_WIDTH(DATA_WIDTH),
      .ADDR_WIDTH(ADDR_WIDTH)
    ) inst (
      .clk(clk),
      .reset_n(reset_n),
      .addr_i(addr_i),
      .ce_i(ce_i),
      .we_i(we[i]),
      .rdata_o(rdata_internal[i]),
      .rvalid_o(rvalid_internal[i]),
      .wack_o(wack_internal[i])
    );
  end endgenerate

  logic [(ADDR_WIDTH+DATA_WIDTH)-1:0] latestWittenLine;
  always_ff @(posedge clk or negedge reset_n) begin
    if(~reset_n) begin
      latestWittenLine <= '0;
    end else if (wack_o) begin
      latestWittenLine <= {addr_i, wdata_i};
    end
  end

  wire latestWittenLine_hit;
  assign latestWittenLine_hit = addr_i == latestWittenLine[(ADDR_WIDTH+DATA_WIDTH)-1:DATA_WIDTH];
  assign rdata_o  = latestWittenLine_hit ?
                    latestWittenLine[DATA_WIDTH-1:0] :
                    rdata_c;
  assign rvalid_o = latestWittenLine_hit | |rvalid_internal;
endmodule
