module alpu_cache #(
  parameter DATA_WIDTH = 16,
  parameter ADDR_WIDTH = 8,

  //IDX used to work out if operand is local or foreign
  parameter ALPU_IDX = 0
) (
  input  wire                   clk,
  input  wire                   reset_n,

  // ALPU interface
  // 2 buses: operands read, result write
  output wire  [DATA_WIDTH-1:0] alpu_r0data,
  output wire                   alpu_r0valid,

  output wire  [DATA_WIDTH-1:0] alpu_r1data,
  output wire                   alpu_r1valid,

  input  wire  [DATA_WIDTH-1:0] alpu_w0data,
  input  wire  [ADDR_WIDTH-1:0] alpu_w0addr,
  input  wire                   alpu_w0valid,

  // Interconnect interface
  // 2 buses: operands write, operand read
  input  wire  [DATA_WIDTH-1:0] icon_w0data,
  input  wire  [ADDR_WIDTH-1:0] icon_w0addr,
  input  wire                   icon_w0valid,

  input  wire  [DATA_WIDTH-1:0] icon_w1data,
  input  wire  [ADDR_WIDTH-1:0] icon_w1addr,
  input  wire                   icon_w1valid,
  
  output wire  [DATA_WIDTH-1:0] icon_r0data,
  output wire                   icon_r0valid,

  // Instruction reqeusts (to be from IQUEUE)
  // 2 buses: operands read request, foreign data prefetch (WIP)
  // no need for valid. Instructions always contain 3 valid addresses
  input  wire  [ADDR_WIDTH-1:0] ireq_r0addr,
  input  wire  [ADDR_WIDTH-1:0] ireq_r1addr,
  input  wire  [ADDR_WIDTH-1:0] ireq_w0addr

  /*input  wire  [ADDR_WIDTH-1:0] addr_i,
  input  wire  [DATA_WIDTH-1:0] wdata_i,

  input  wire                   ce_i,
  input  wire                   yx_we_i,

  output wire  [DATA_WIDTH-1:0] rdata_o,
  //if tag address does not match on read, then read is invalid
  output wire                   rvalid_o,
  //if address writing to has not already been read, then write has not been acknowledged
  output wire                   wack_o*/
);
  
  // -----------------------------------------------------
  // Local (Y) buffers
  // Using method 2 as written in ALU onenote section
  // -----------------------------------------------------
  wire y_r0data;
  wire y_r0hit;
  wire y_r1data;
  wire y_r1hit;

  //ys buffer (stores ALPU most recently returned result)
  logic [DATA_WIDTH-1:0] ys_data;
  logic [ADDR_WIDTH-1:0] ys_addr;
  wire                   ys_hit0; //op0 hit
  wire                   ys_hit1; //op1 hit
  wire                   ys_hit;
  always_ff @(posedge clk or negedge reset_n) begin
    if(~reset_n) begin
      ys_data = '0;
    end else if (alpu_w0valid) begin
      ys_data = alpu_w0data;
      ys_addr = alpu_w0addr;
    end
  end
  assign ys_hit0 = ireq_r0addr == ys_addr;
  assign ys_hit1 = ireq_r1addr == ys_addr;
  assign ys_hit  = ys_hit0 | ys_hit1;

  //rw swap markers
  //controls which bank is read and which is write
  wire [1:0] yx_we;
  logic yx_rw_swap;
  always_ff @(posedge clk or negedge reset_n) begin
    if(~reset_n) begin
      yx_rw_swap <= '0;
    end else begin
      yx_rw_swap = ~yx_rw_swap;
    end
  end
  //assign write enables. If ys_hit, set both to read
  assign yx_we[0] =  yx_rw_swap & ~ys_hit;
  assign yx_we[1] = ~yx_rw_swap & ~ys_hit;

  wire [1:0] [DATA_WIDTH-1:0] yx_rdata;
  wire                  [1:0] yx_rhit;
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
      .yx_we_i(yx_we[i]),
      .rdata_o(yx_rdata[i]),
      .rhit_o(yx_rhit[i]),
      .wack_o(yx_wack[i])
    );
  end endgenerate

  //combine read signals to signal read out from local (y)
  assign y_r0hit = ys_hit0 | |yx_rhit;
                    
  // -----------------------------------------------------
  // Foreign (X) buffers
  // -----------------------------------------------------



endmodule
