module alpu_cache #(
  parameter DATA_WIDTH = 16,

  //IDX used to work out if operand is local or foreign
  parameter ALPU_IDX = 0,
  parameter LOG2_NUM_ALPU = 2, //total number of alpus

  parameter LOG2_NUM_REG = 2, //total number of registers in file

  localparam ADDR_WIDTH = LOG2_NUM_REG + LOG2_NUM_ALPU + 2
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
  input  wire  [ADDR_WIDTH-1:0] alpu_w0addr, //contains opd of CURRENT instruction
  //input  wire  [ADDR_WIDTH-1:0] alpu_w0addr_q, //contains opd of NEXT instruction. If equal to current opd, cancel write to cache
                                              //as next cycle the shortcut buffer with be hit
  input  wire                   alpu_w0valid, //w0 can be invalid if no instruction is being processed
  //input  wire                   alpu_w0valid_q,
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
  input  wire  [ADDR_WIDTH-1:0] icon_r0addr,
  output wire                   icon_r0valid,

  // Instruction reqeusts (to be from IQUEUE)
  // 2 buses: operands read request, foreign data prefetch (WIP)
  // no need for valid on write. Instructions always write to some cache
  // if address is invalid, then ireq contained immediate for operand
  input  wire  [ADDR_WIDTH-1:0] ireq_r0addr,
  input  wire                   ireq_r0addr_valid,
  input  wire  [ADDR_WIDTH-1:0] ireq_r1addr,
  input  wire                   ireq_r1addr_valid
  //input  wire  [ADDR_WIDTH-1:0] ireq_w0addr //w0 will come from ALPU as it will make ALPU pipelines easier to implement
);
  

  typedef struct packed {
    logic [LOG2_NUM_ALPU-1:0] alpu_idx;
    logic                     is_output; //i.e. not intermediate and to send back to main reg file
    logic  [LOG2_NUM_REG-1:0] reg_idx;
    logic                     opx; //op0 if 0, op1 if 1
  } type_addr;

  typedef struct packed {
    logic [DATA_WIDTH-1:0] data;
    logic                  has_been_read;
  } type_data_entry;

  //calc if alpu w0 destination is to local or foreign
  type_addr alpu_w0addr_cast;
  wire      alpu_w0addr_y_or_x;
  assign alpu_w0addr_cast   = alpu_w0addr;
  assign alpu_w0addr_y_or_x = ALPU_IDX == alpu_w0addr_cast.alpu_idx;
  
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
    end else if (alpu_w0valid) begin
      ys_data  <= alpu_w0data;
      ys_addr  <= alpu_w0addr;
      ys_valid <= 1'b1;
    end else begin
      ys_valid <= 1'b0;
    end
  end
  assign ys_hit0 = ireq_r0addr == ys_addr;
  assign ys_hit1 = ireq_r1addr == ys_addr;
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
  assign yx_we[0] =  yx_rw_swap & ~ys_hit & alpu_w0valid;
  assign yx_we[1] = ~yx_rw_swap & ~ys_hit & alpu_w0valid;

  //resolve signals to be passed to cache banks
  //check for write back cancel (i.e. guaranteed shortcut hit)
  //wire yx_w_cancel;
  //assign yx_w_cancel = alpu_w0addr == alpu_w0addr_q;

  logic [1:0] [ADDR_WIDTH-1:0] yx_addra; //either op1 when both marked for read (i.e. on ys_hit) else opd
  logic       [ADDR_WIDTH-1:0] yx_addra_valid;
  logic [1:0] [ADDR_WIDTH-1:0] yx_addrb;
  logic                        yx_addrb_valid;
  always_comb begin: addrab_assigns
    if (ys_hit) begin: mode_rr //on ys_hit, cancel write (and therefore has_been_read check)
      yx_addra[0]     = ireq_r1addr;
      yx_addra[1]     = ireq_r1addr;
      yx_addra_valid  = ireq_r1addr_valid;
      yx_addrb[0]     = ireq_r0addr;
      yx_addrb[1]     = ireq_r0addr;
      yx_addrb_valid  = ireq_r0addr_valid;
    end else begin: mode_rw
      yx_addra[0]     = yx_we[0] ? ys_addr     : ireq_r0addr;
      yx_addra[1]     = yx_we[1] ? ys_addr     : ireq_r0addr;
      yx_addra_valid  = ys_valid | ireq_r0addr_valid;
      yx_addrb[0]     = yx_we[0] ? ireq_r1addr : alpu_w0addr;
      yx_addrb[1]     = yx_we[1] ? ireq_r1addr : alpu_w0addr;
      yx_addrb_valid  = alpu_w0valid | ireq_r1addr_valid;
    end
  end

  type_data_entry [1:0] yx_rdataa;
  type_data_entry [1:0] yx_rdatab;
  type_data_entry       yx_wdata;
  wire       [1:0] yx_rhita;
  wire       [1:0] yx_rhitb;

  assign yx_wdata.data          = ys_data;
  assign yx_wdata.has_been_read = 1'b0;
  generate for (genvar i = 0; i < 2; i++) begin: g_yx
    cache_DP #(
      .IDX_BITS(2),
      .DATA_WIDTH($bits(type_data_entry)),
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

  logic [DATA_WIDTH-1:0] alpu_r0data_internal;
  logic [DATA_WIDTH-1:0] alpu_r1data_internal;
  logic                  alpu_rx_ready_internal;
  always_comb begin : route_alpu_r //TODO: check for duplicates
    logic alpu_r0_ready_internal;
    logic alpu_r1_ready_internal;
    alpu_r0data_internal = '0;
    alpu_r1data_internal = '0;
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
  typedef enum logic {
    DIR_TX = 1'b0,
    DIR_RX = 1'b1
  } type_foreign_dir;

  //RX buffers
  wire x_r0data;
  wire x_r1data;
  type_data_entry [1:0] x_rxdata;
  generate for (genvar i = 0; i < 2; i++) begin: g_xrx
    cache_SRW #(
      .IDX_BITS(2),
      .DATA_WIDTH($bits(type_data_entry)),
      .ADDR_WIDTH(ADDR_WIDTH)
    ) xbuf (
      .clk(clk),
      .reset_n(reset_n),
      .waddr_i(waddr),
      .raddr_i(raddr),
      .ce_i(),
      .we_i(),
      .rdata_o(),
      .wdata_i(),
      .rhit_o(),
    );
  end endgenerate

  //order matters, two rxs must be next to each other due to lazy assignments in generate
  localparam type_foreign_dir[2:0] FOREIGN_BUF_DIRS = {DIR_RX, DIR_RX, DIR_TX};
  generate for (genvar i = 0; i < 3; i++) begin: g_xx
    logic [ADDR_WIDTH-1:0] waddr;
    logic [ADDR_WIDTH-1:0] raddr;

    always_comb: begin
      if (FOREIGN_BUF_DIRS[i] == DIR_RX) begin
        waddr = (i % 2) ? icon_w0addr : icon_w1addr;
        raddr = (i % 2) ? alpu_r0addr : alpu_r1addr;
      end else begin
        waddr = alpu_w0addr;
        raddr = icon_r0addr;
      end
    end

    cache_SRW #(
      .IDX_BITS(2),
      .DATA_WIDTH($bits(type_data_entry)),
      .ADDR_WIDTH(ADDR_WIDTH)
    ) xbuf (
      .clk(clk),
      .reset_n(reset_n),
      .waddr_i(waddr),
      .raddr_i(raddr),
      .ce_i(),
      .we_i(),
      .rdata_o(),
      .wdata_i(),
      .rhit_o(),
    );
  end endgenerate

endmodule

/*if (ys_hit) begin: mode_rr
      for (int i = 0; i < 2; i++) begin
        if(yx_rhita[i] & ~yx_rdataa[i].has_been_read) begin
          alpu_r0data_internal |= yx_rdataa[i].data;
          alpu_r0_ready_internal |= 1'b1;
        end
        if (yx_rhitb[i] & ~yx_rdatab[i].has_been_read) begin
          alpu_r1data_internal   |= yx_rdatab[i].data;
          alpu_r1_ready_internal |= 1'b1;
        end
      end
    end else begin: mode_rw*/
  //end
