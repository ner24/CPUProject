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

  output wire                   alpu_rx_ready,

  input  wire  [DATA_WIDTH-1:0] alpu_w0data,
  input  wire  [ADDR_WIDTH-1:0] alpu_w0addr,
  input  wire                   alpu_w0valid, //w0 can be invalid if no instruction is being processed
  output wire                   alpu_w0ready,

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
  // no need for valid on write. Instructions always write to some cache
  // if address is invalid, then ireq contained immediate for operand
  input  wire  [ADDR_WIDTH-1:0] ireq_r0addr,
  input  wire                   ireq_r0addr_valid,
  input  wire  [ADDR_WIDTH-1:0] ireq_r1addr,
  input  wire                   ireq_r1addr_valid,
  //input  wire  [ADDR_WIDTH-1:0] ireq_w0addr //w0 will come from ALPU as it will make ALPU pipelines easier to implement

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

  typedef struct packed {
    logic [DATA_WIDTH-1:0] data;
    logic                  has_been_read;
  } entry_data;
  
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
  always_ff @(posedge clk /*or negedge reset_n*/) begin
    if(~reset_n) begin
      ys_data <= '0;
      ys_addr <= '0;
    end else if (alpu_w0valid) begin
      ys_data <= alpu_w0data;
      ys_addr <= alpu_w0addr;
    end
  end
  assign ys_hit0 = ireq_r0addr == ys_addr;
  assign ys_hit1 = ireq_r1addr == ys_addr;
  assign ys_hit  = ys_hit0 | ys_hit1;

  //rw swap markers
  //controls which bank is read and which is write
  wire [1:0] yx_we; //1 = w, 0 = r
  logic yx_rw_swap;
  always_ff @(posedge clk /*or negedge reset_n*/) begin
    if(~reset_n) begin
      yx_rw_swap <= '0;
    end else begin
      yx_rw_swap <= ~yx_rw_swap;
    end
  end
  //assign write enables. If ys_hit, set both to read
  assign yx_we[0] =  yx_rw_swap & ~ys_hit & alpu_w0valid;
  assign yx_we[1] = ~yx_rw_swap & ~ys_hit & alpu_w0valid;

  //resolve signals to be passed to cache banks
  wire [1:0] [ADDR_WIDTH-1:0] yx_addra; //either op1 when both marked for read (i.e. on ys_hit) else opd
  wire       [ADDR_WIDTH-1:0] yx_addra_valid;
  wire       [ADDR_WIDTH-1:0] yx_addrb;
  wire                        yx_addrb_valid;
  assign yx_addra[0]    = yx_we[0] ? ys_addr : ireq_r1addr;
  assign yx_addra[1]    = yx_we[1] ? ys_addr : ireq_r1addr;
  assign yx_addra_valid = alpu_w0valid | ireq_r1addr_valid;
  assign yx_addrb       = ireq_r0addr;
  assign yx_addrb_valid = ireq_r0addr_valid;

  entry_data [1:0] /*[DATA_WIDTH-1:0]*/ yx_rdataa;
  entry_data [1:0] /*[DATA_WIDTH-1:0]*/ yx_rdatab;
  wire                  [1:0] yx_rhita;
  wire                  [1:0] yx_rhitb;

  generate for (genvar i = 0; i < 2; i++) begin: g_cache
    cache_DP #(
      .IDX_BITS(2),
      .DATA_WIDTH($bits(entry_data)),
      .ADDR_WIDTH(ADDR_WIDTH)
    ) inst (
      .clk(clk),
      .reset_n(reset_n),
      .addra_i(yx_addra[i]), //points to op0 or opd depending on read or write
      .addrb_i(yx_addrb), //points to op1
      .cea_i(yx_addra_valid),
      .ceb_i(yx_addrb_valid),
      .we_i(yx_we[i]),
      .rdataa_o(yx_rdataa[i]),
      .rdatab_o(yx_rdatab[i]),
      .wdata_i({ys_data, 1'b0}), //LSB is has_been_read flag
      .rhita_o(yx_rhita[i]),
      .rhitb_o(yx_rhitb[i])
    );
  end endgenerate

  logic [DATA_WIDTH-1:0] alpu_r0data_internal;
  logic [DATA_WIDTH-1:0] alpu_r1data_internal;
  logic                  alpu_rx_ready_internal;
  always_comb begin : calc_alpu_rdatas //TODO: check for duplicates
    logic alpu_r0_ready_internal;
    logic alpu_r1_ready_internal;
    alpu_r0data_internal = '0;
    alpu_r1data_internal = '0;
    alpu_rx_ready_internal = 1'b0;
    for (int i = 0; i < 2; i++) begin
      if (yx_rhita[i] & ~yx_rdataa[i].has_been_read & ~yx_we[i]) begin
        alpu_r0data_internal   |= yx_rdataa[i].data;
        alpu_r0_ready_internal |= 1'b1;
      end
      if (yx_rhitb[i] & ~yx_rdatab[i].has_been_read) begin
        alpu_r1data_internal   |= yx_rdatab[i].data;
        alpu_r1_ready_internal |= 1'b1;
      end
    end
    alpu_rx_ready_internal = alpu_r0_ready_internal & alpu_r1_ready_internal;
  end
  assign alpu_r0data    = alpu_r0data_internal;
  assign alpu_r1data    = alpu_r1data_internal;
  assign alpu_ops_ready = alpu_rx_ready_internal; //|(~yx_we & yx_rhita) | (|yx_rhitb);
  
  // -----------------------------------------------------
  // Foreign (X) buffers
  // -----------------------------------------------------



endmodule
