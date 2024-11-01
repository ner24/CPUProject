module alpu_cache_xbuf import exec_unit_dtypes::*; #( //simultaneous read write
  parameter IDX_BITS = 2
) (
  input  wire                     clk,
  input  wire                     reset_n,

  input  wire type_exec_unit_addr waddr_i,
  input  wire type_exec_unit_addr raddr_i,

  input  wire                     wvalid_i,
  input  wire                     rvalid_i,

  input  wire type_exec_unit_data wdata_i,
  output wire type_exec_unit_data rdata_o,

  //if tag address does not match on read, then read is invalid
  output wire                     rhit_o,
  output wire                     wready_o
);

  type_exec_unit_data wdata;
  assign wdata.data          = wdata_i;
  //assign wdata.has_been_read = 1'b0;

  type_exec_unit_data rdata; //NOTE: used to get data width; has_been_read field is unconnected here
  assign rdata_o = rdata.data;

  //check for collision. If there is, cancel write and use bypass
  //works as an optimisation and avoids RAM collisions
  wire collision;
  assign collision = waddr_i == raddr_i;

  wire [IDX_BITS-1:0] ridx;
  wire [IDX_BITS-1:0] widx;
  assign ridx = raddr_i[IDX_BITS-1:0];
  assign widx = waddr_i[IDX_BITS-1:0];

  //chip enables
  wire xbuf_ce;
  wire xbuf_we;
  wire waddr_ready;
  assign xbuf_ce = ~collision & (wvalid_i | rvalid_i);
  assign xbuf_we = wvalid_i & waddr_ready;
  assign wready_o = waddr_ready;

  //has_been_read buffer
  //this will be smaller in area than having swap buffers
  //for small numbers of entries. (Considering the number of requried I/O signals)
  logic [(2**IDX_BITS)-1:0] has_been_read_buf;
  wire rhit, xbuf_rhit;
  assign rhit = ~has_been_read_buf[ridx] & xbuf_rhit;
  always_ff @(posedge clk) begin
    if (~reset_n) begin
      has_been_read_buf = {(2**IDX_BITS)-1{1'b1}};
    end else begin
      if (rhit) begin
        //rdata.has_been_read = 1'b1;
        has_been_read_buf[ridx] = 1'b1;
      end
      if (has_been_read_buf[widx]) begin
        has_been_read_buf[widx] = 1'b0;
      end
    end
  end
  assign waddr_ready = has_been_read_buf[widx];
  assign rhit_o = rhit;

  cache_SRW #(
    .IDX_BITS(2),
    .DATA_WIDTH($bits(type_exec_unit_data)),
    .ADDR_WIDTH($bits(type_exec_unit_addr))
  ) xbuf (
    .clk(clk),
    .reset_n(reset_n),
    .waddr_i(waddr_i),
    .raddr_i(raddr_i),
    .ce_i(xbuf_ce),
    .we_i(xbuf_we),
    .rdata_o(rdata),
    .wdata_i(wdata),
    .rhit_o(xbuf_rhit)
  );

endmodule
