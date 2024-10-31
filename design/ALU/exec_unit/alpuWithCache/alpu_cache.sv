module alpu_cache import exec_unit_dtypes::*; #(
  //IDX used to work out if operand is local or foreign
  parameter eu_idx = 0
) (
  input  wire                   clk,
  input  wire                   reset_n,

  // ALPU interface
  // 2 buses: operands read, result write
  output wire type_alpu_channel_rx alpu_rx,
  input  wire type_alpu_channel_tx alpu_tx,

  // Interconnect interface
  // 3 channels: operands write, operand read
  input  wire type_icon_channel    icon_w0,
  output wire type_icon_rx_channel icon_w0_rx,
  input  wire type_icon_channel    icon_w1,
  output wire type_icon_rx_channel icon_w1_rx,
  
  //not using type_icon_channel since attributes go in different directions
  output wire  [DATA_WIDTH-1:0] icon_r0data,
  input  wire    type_icon_addr icon_r0addr,
  output wire                   icon_r0valid,
  input  wire                   icon_r0ready,

  // Instruction reqeusts (from IQUEUE)
  // 2 buses: operands read request, foreign data prefetch (WIP)
  // no need for valid on write. Instructions always write to some cache
  // if address is invalid, then ireq contained immediate for operand
  input  wire type_iqueue_entry ireq_curr_instr
);
  localparam ADDR_WIDTH = 4; //temp

  //calc if operands are to/from local or foreign
  wire op0_yorx;
  wire op1_yorx;
  wire opd_yorx;
  assign op0_yorx = eu_idx == ireq_curr_instr.op0.as_addr.eu_idx; //1 = local (y), 0 = foreign (x)
  assign op1_yorx = eu_idx == ireq_curr_instr.op1.as_addr.eu_idx;
  assign opd_yorx = eu_idx == alpu_tx.opd_addr.eu_idx;
  
  // -----------------------------------------------------
  // Local (Y) buffers
  // Using method 2 as written in ALU onenote section
  // -----------------------------------------------------

  //ys buffer (stores ALPU most recently returned result)
  //TODO: connect alpu_rx.opd_ready signal so alpu can stall when required
  logic [DATA_WIDTH-1:0] ys_data;
  logic [ADDR_WIDTH-1:0] ys_addr;
  logic                  ys_valid; //if read but not written, set to false
                                  //means no data was added. Better for power
                                  //to have it not constantly write the same data
  wire                   ys_hit0; //op0 hit
  wire                   ys_hit1; //op1 hit
  wire                   ys_hit;
  always_ff @(posedge clk) begin
    if(~reset_n) begin
      ys_data  <= 'x;
      ys_addr  <= 'x; //add x to simplify reset logic
      ys_valid <= '0;
    end else if (alpu_tx.opd_valid & opd_yorx) begin
      ys_data  <= alpu_tx.opd_data;
      ys_addr  <= alpu_tx.opd_addr;
      ys_valid <= 1'b1;
    end else begin
      ys_valid <= 1'b0;
    end
  end
  assign ys_hit0 = ireq_curr_instr.op0m & (ireq_curr_instr.op0.as_addr == ys_addr);
  assign ys_hit1 = ireq_curr_instr.op1m & (ireq_curr_instr.op1.as_addr == ys_addr);
  assign ys_hit  = ys_hit0 | ys_hit1;

  //rw swap markers
  //controls which bank is read and which is write
  wire [1:0] yx_we; //1 = w, 0 = r
  logic yx_rw_swap;
  always_ff @(posedge clk) begin
    if(~reset_n) begin
      yx_rw_swap <= 1'b0;
    end else begin
      yx_rw_swap <= ~yx_rw_swap;
    end
  end
  //assign write enables. If ys_hit, set both to read
  assign yx_we[0] =  yx_rw_swap & ~ys_hit & alpu_tx.opd_valid;
  assign yx_we[1] = ~yx_rw_swap & ~ys_hit & alpu_tx.opd_valid;

  //resolve signals to be passed to cache banks
  //check for write back cancel (i.e. guaranteed shortcut hit)
  //wire yx_w_cancel;
  //assign yx_w_cancel = alpu_tx.opd_addr == alpu_tx.opd_addr_q;

  logic [1:0] [ADDR_WIDTH-1:0] yx_addra; //either op1 when both marked for read (i.e. on ys_hit) else opd
  logic       [ADDR_WIDTH-1:0] yx_addra_valid;
  logic [1:0] [ADDR_WIDTH-1:0] yx_addrb;
  logic                        yx_addrb_valid;
  always_comb begin: addrab_assigns
    if (ys_hit | opd_yorx) begin: mode_rr //on ys_hit or foreign opd, cancel write (and therefore has_been_read check)
      yx_addra[0]     = ireq_curr_instr.op1;
      yx_addra[1]     = ireq_curr_instr.op1;
      yx_addra_valid  = ireq_curr_instr.op1m;
      yx_addrb[0]     = ireq_curr_instr.op0;
      yx_addrb[1]     = ireq_curr_instr.op0;
      yx_addrb_valid  = ireq_curr_instr.op0m;
    end else begin: mode_rw
      yx_addra[0]     = yx_we[0] ? ys_addr     : ireq_curr_instr.op0;
      yx_addra[1]     = yx_we[1] ? ys_addr     : ireq_curr_instr.op0;
      yx_addra_valid  = ys_valid | ireq_curr_instr.op0m;
      yx_addrb[0]     = yx_we[0] ? ireq_curr_instr.op1 : alpu_tx.opd_addr;
      yx_addrb[1]     = yx_we[1] ? ireq_curr_instr.op1 : alpu_tx.opd_addr;
      yx_addrb_valid  = alpu_tx.opd_valid | ireq_curr_instr.op1m;
    end
  end

  type_ycache_data [1:0] yx_rdataa;
  type_ycache_data [1:0] yx_rdatab;
  type_ycache_data       yx_wdata;
  wire       [1:0] yx_rhita;
  wire       [1:0] yx_rhitb;

  assign yx_wdata.data          = ys_data;
  assign yx_wdata.has_been_read = 1'b0;
  generate for (genvar i = 0; i < 2; i++) begin: g_yx
    cache_DP #(
      .IDX_BITS(2),
      .DATA_WIDTH($bits(type_ycache_data)),
      .ADDR_WIDTH(ADDR_WIDTH)
    ) ybuf (
      .clk(clk),
      .reset_n(reset_n),
      .addra_i(yx_addra[i]), //points to op0 or opd depending on read or write
      .addrb_i(yx_addrb[i]), //points to op1
      .cea_i(yx_addra_valid),
      .ceb_i(yx_addrb_valid),
      .we_i(yx_we[i]),
      .rdataa_o(yx_rdataa[i]),
      .rdatab_o(yx_rdatab[i]),
      .wdata_i(yx_wdata),
      .rhita_o(yx_rhita[i]),
      .rhitb_o(yx_rhitb[i])
    );
  end endgenerate

  logic [DATA_WIDTH-1:0] yx_op0data;
  logic [DATA_WIDTH-1:0] yx_op1data;
  logic            [1:0] yx_opx_valid;
  always_comb begin : route_alpu_r //TODO: check for duplicates
    yx_op0data = '0;
    yx_op1data = '0;
    yx_opx_valid = '0;
    for (int i = 0; i < 2; i++) begin
      if (yx_rhita[i] & ~yx_rdataa[i].has_been_read & ~yx_we[i]) begin
        yx_op0data      |= yx_rdataa[i].data;
        yx_opx_valid[0] |= 1'b1;
      end
      if (yx_rhitb[i] & ~yx_rdatab[i].has_been_read) begin
        yx_op1data      |= yx_rdatab[i].data;
        yx_opx_valid[1] |= 1'b1;
      end
    end
  end
  
  // -----------------------------------------------------
  // Foreign (X) buffers
  // -----------------------------------------------------
  
  type_xcache_data  [1:0] xrx_rdata;
  //type_xcache_data  [1:0] xwx_rdata;

  wire              [1:0] xrx_rvalid;

  wire              [1:0] xrx_wready;
  assign icon_w0_rx.ready = xrx_wready[0];
  assign icon_w1_rx.ready = xrx_wready[1];


  //RX buffers
  type_icon_channel [1:0] icon_wx;
  assign icon_wx[0] = icon_w0;
  assign icon_wx[1] = icon_w1;
  type_exec_unit_addr [1:0] xrx_raddr;
  assign xrx_raddr[0] = ireq_curr_instr.op0.as_addr;
  assign xrx_raddr[1] = ireq_curr_instr.op1.as_addr;
  wire [1:0] xrx_raddr_valid;
  assign xrx_raddr_valid[0] = ireq_curr_instr.op0m & ~op0_yorx;
  assign xrx_raddr_valid[1] = ireq_curr_instr.op1m & ~op1_yorx;

  generate for (genvar i = 0; i < 2; i++) begin: g_xrx
    alpu_cache_xbuf #(
      .IDX_BITS(2)
    ) xbuf (
      .clk(clk),
      .reset_n(reset_n),
      .waddr_i(icon_wx[i].addr),
      .raddr_i(xrx_raddr[i]),
      .wvalid_i(icon_wx[i].valid),
      .rvalid_i(xrx_raddr_valid[i]),
      .wdata_i(icon_wx[i].data),
      .rdata_o(xrx_rdata[i]),
      .rhit_o(xrx_rvalid[i]),
      .wready_o(xrx_wready[i])
    );
  end endgenerate

  //TX buffer
  wire xtx_wready;
  alpu_cache_xbuf #(
    .IDX_BITS(2)
  ) xtx_buf (
    .clk(clk),
    .reset_n(reset_n),
    .waddr_i(alpu_tx.opd_addr),
    .raddr_i(icon_r0addr),
    .wvalid_i(alpu_tx.opd_valid & ~opd_yorx),
    .rvalid_i(icon_r0ready),
    .wdata_i(alpu_tx.opd_data),
    .rdata_o(icon_r0data),
    .rhit_o(icon_r0valid),
    .wready_o(xtx_wready)
  );

  // --------------------------------
  // wire X and Y to alpu intf
  // --------------------------------
  assign alpu_rx.op0_data  = op0_yorx ? yx_op0data      : xrx_rdata[0];
  assign alpu_rx.op1_data  = op1_yorx ? yx_op1data      : xrx_rdata[1];
  assign alpu_rx.op0_valid = op0_yorx ? yx_opx_valid[0] : xrx_rvalid[0];
  assign alpu_rx.op1_valid = op1_yorx ? yx_opx_valid[1] : xrx_rvalid[1];
  assign alpu_rx.opd_ready = opd_yorx ? 1'b0 : xtx_wready;

endmodule
