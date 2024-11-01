//temp file to contain rewritten code
//this will eventually become alpu_cache.sv when old is deleted

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
  input  wire type_icon_channel    icon_w0, //for op0
  output wire type_icon_rx_channel icon_w0_rx,
  input  wire type_icon_channel    icon_w1, //for op1
  output wire type_icon_rx_channel icon_w1_rx,
  
  //not using type_icon_channel since attributes go in different directions
  output wire type_exec_unit_data  icon_r0data,
  input  wire type_exec_unit_addr  icon_r0addr,
  output wire                      icon_r0valid,
  input  wire                      icon_r0ready,

  // Instruction reqeusts (from IQUEUE)
  // 2 buses: operands read request, foreign data prefetch (WIP)
  // no need for valid on write. Instructions always write to some cache
  // if address is invalid, then ireq contained immediate for operand
  input  wire type_iqueue_entry ireq_curr_instr
);
  localparam YBUF_IDX_BITS = $bits(type_alpu_local_addr) > 2 ? 2 : $bits(type_alpu_local_addr);
  localparam XBUF_IDX_BITS = $bits(type_exec_unit_addr) > 2 ? 2 : $bits(type_exec_unit_addr);

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
  //rw swap markers
  //controls which bank is read and which is write
  wire [1:0] yx_rw; //1 = w, 0 = r
  logic yx_rw_swap;
  always_ff @(posedge clk) begin
    if(~reset_n) begin
      yx_rw_swap <= 1'b0;
    end else begin
      yx_rw_swap <= ~yx_rw_swap;
    end
  end

  //check that yx buffers are ready for write (has_been_read check)
  logic yx_wready;

  //ys buffer
  typedef struct packed {
    type_exec_unit_data  data;
    type_alpu_local_addr addr;
    logic                valid;
  } type_ys_buf;
  type_ys_buf ys;
  
  wire  [1:0] ys_opx_hit;
  wire        ys_hit;
  always_ff @(posedge clk) begin
    if(~reset_n) begin
      ys.data  <= 'x;
      ys.addr  <= 'x; //add x to simplify reset logic
      ys.valid <= 1'b0;
    end else if (alpu_tx.opd_valid & opd_yorx & yx_wready) begin //TODO: assign yx_wready
      ys.data  <= alpu_tx.opd_data;
      ys.addr  <= alpu_tx.opd_addr;
      ys.valid <= 1'b1;
    end else begin
      ys.valid <= 1'b0;
    end
  end
  assign ys_opx_hit[0] = ireq_curr_instr.op0m & (ireq_curr_instr.op0.as_addr == ys.addr);
  assign ys_opx_hit[1] = ireq_curr_instr.op1m & (ireq_curr_instr.op1.as_addr == ys.addr);
  assign ys_hit        = (|ys_opx_hit) & ys.valid;

  //assign write enables. If ys_hit, set both to read
  assign yx_rw[0] =  yx_rw_swap;
  assign yx_rw[1] = ~yx_rw_swap;
  wire mode_rr; 
  assign mode_rr = ys_hit | opd_yorx;//TODO: opd_yorx needs to be flopped once here

  //input wires for yx swap buffers (indexed by [y buffer idx][buffer port 0 (a) or 1 (b)])
  type_alpu_local_addr [1:0] [1:0] yx_addrx;
  type_ycache_data                 yx_wdata; //common across both buffers
  logic                [1:0] [1:0] yx_cex;
  logic                      [1:0] yx_wex;
  always_comb begin: yx_assigns
    yx_wex = 2'b00;
    if (mode_rr) begin: mode_rr
      //in rr mode, both buffers are used identically.
      //Port 0 used to read op0 and port 1 for op1
      for (int i = 0; i < 2; i++) begin
        yx_addrx[i][0] = ireq_curr_instr.op0;
        yx_addrx[i][1] = ireq_curr_instr.op1;
        yx_cex[i][0]   = ireq_curr_instr.op0m;
        yx_cex[i][1]   = ireq_curr_instr.op1m;
      end
    end else begin: mode_rw
      //in rw mode the following is used:
      //w marked bank: r = ireq op1 addr (port 0)
      //               w = ys addr       (port 1)
      //r marked bank: r = alpu opd addr (port 0)
      //               r = ireq op0 addr (port 1)

      for (int i = 0; i < 2; i++) begin
        yx_addrx[i][0] = yx_rw[i] ? ireq_curr_instr.op1  : alpu_tx.opd_addr;
        yx_addrx[i][1] = yx_rw[i] ? ys.addr              : ireq_curr_instr.op0;
        yx_cex[i][0]   = yx_rw[i] ? ireq_curr_instr.op1m : alpu_tx.opd_valid;
        yx_cex[i][1]   = yx_rw[i] | ireq_curr_instr.op0m ;
        
        yx_wex[i] = yx_rw[i] & alpu_tx.opd_valid; //Dont need yx_wready here as buffers will be in rr mode if low
      end
    end
  end
  assign yx_wdata.data          = ys.data;
  assign yx_wdata.has_been_read = 1'b0;

  //yx read buses
  type_ycache_data [1:0] [1:0] yx_rdatax;
  wire             [1:0] [1:0] yx_rhitx;
  generate for (genvar i = 0; i < 2; i++) begin: g_yx
    cache_DP #(
      .IDX_BITS(YBUF_IDX_BITS),
      .DATA_WIDTH($bits(type_ycache_data)),
      .ADDR_WIDTH($bits(type_alpu_local_addr))
    ) ybuf (
      .clk(clk),
      .reset_n(reset_n),
      .addra_i(yx_addrx[i][0]), //points to op0 or opd depending on read or write
      .addrb_i(yx_addrx[i][1]), //points to op1
      .cea_i(yx_cex[i][0]),
      .ceb_i(yx_cex[i][1]),
      .we_i(yx_wex[i]),
      .rdataa_o(yx_rdatax[i][0]),
      .rdatab_o(yx_rdatax[i][1]),
      .wdata_i(yx_wdata),
      .rhita_o(yx_rhitx[i][0]),
      .rhitb_o(yx_rhitx[i][1])
    );
  end endgenerate

  //resolve op0, op1 and operand valids (also yx_wready)
  //see yx_assigns block for description
  type_exec_unit_data [1:0] y_opxData;
  logic               [1:0] y_opxValid;
  always_comb begin: route_alpu_ops
    if (mode_rr) begin: mode_rr
      //if hit on bank 0, use that, else assign to bank 1 (even if invalid, in which case valid bits will be low)
      y_opxData[0]  <= yx_rhitx[0][0] ? yx_rdatax[0][0] : yx_rdatax[1][0];
      y_opxData[1]  <= yx_rhitx[0][1] ? yx_rdatax[0][1] : yx_rdatax[1][1];
      y_opxValid[0] <= yx_rhitx[0][0] | yx_rhitx[1][0]; //TODO: assert that yx_rhitx is one hot per operand (i.e no duplicates)
      y_opxValid[1] <= yx_rhitx[0][1] | yx_rhitx[1][1];

      yx_wready <= 1'b0;
    end else begin: mode_rw
      y_opxData[0]  <= yx_rw[0] ? yx_rdatax[1][1] : yx_rdatax[0][1];
      y_opxData[1]  <= yx_rw[0] ? yx_rdatax[0][0] : yx_rdatax[1][0];
      y_opxValid[0] <= yx_rw[0] ? yx_rhitx[1][1]  : yx_rhitx[0][1];
      y_opxValid[1] <= yx_rw[0] ? yx_rhitx[0][0]  : yx_rhitx[1][0];

      yx_wready <= yx_rw[0] ? yx_rdatax[0][1].has_been_read : yx_rdatax[1][1].has_been_read;
    end
  end

  // -----------------------------------------------------
  // Foreign (X) buffers
  // -----------------------------------------------------

  type_exec_unit_data [1:0] xrx_rdata;
  wire                [1:0] xrx_rvalid;
  wire                [1:0] xrx_wready;

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
      .IDX_BITS(XBUF_IDX_BITS)
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
    .IDX_BITS(XBUF_IDX_BITS)
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
  assign alpu_rx.op0_data  = ireq_curr_instr.op0m ? (op0_yorx ? y_opxData[0]  : xrx_rdata[0])  : ireq_curr_instr.op0.as_immediate.data;
  assign alpu_rx.op1_data  = ireq_curr_instr.op1m ? (op1_yorx ? y_opxData[1]  : xrx_rdata[1])  : ireq_curr_instr.op1.as_immediate.data;
  assign alpu_rx.op0_valid = ireq_curr_instr.op0m ? (op0_yorx ? y_opxValid[0] : xrx_rvalid[0]) : 1'b1;
  assign alpu_rx.op1_valid = ireq_curr_instr.op1m ? (op1_yorx ? y_opxValid[1] : xrx_rvalid[1]) : 1'b1;
  assign alpu_rx.opd_addr  = ireq_curr_instr.opd;
  assign alpu_rx.opd_ready = opd_yorx ? 1'b0 : xtx_wready;

endmodule
