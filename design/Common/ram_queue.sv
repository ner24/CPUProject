module ram_queue # ( //TODO: replace pointers with JK flip flop counters for smaller power and area
  parameter DATA_WIDTH = 4,
  parameter LOG2_SIZE = 2
) (
  input wire clk,
  input wire reset_n,

  input  wire                  wvalid_i,
  input  wire [DATA_WIDTH-1:0] wdata_i,

  output wire                  full_o,
  output wire                  empty_o,

  input  wire                  rready_i,
  output wire [DATA_WIDTH-1:0] rdata_o
);

  localparam ADDR_WIDTH = LOG2_SIZE;

  wire wvalid;
  wire rvalid;

  logic [ADDR_WIDTH-1:0] waddr;
  logic [ADDR_WIDTH-1:0] raddr;

  logic [ADDR_WIDTH-1:0] ptr_head;// [1:0];
  logic [ADDR_WIDTH-1:0] ptr_tail;// [1:0];
  //logic swap;
  logic full;
  wire  empty;

  assign wvalid = wvalid_i & ~full;
  assign rvalid = rready_i & ~empty;
  always_ff @(posedge clk) begin: ff_ptrs
    if(~reset_n) begin
      ptr_head = {ADDR_WIDTH{1'b0}};
      //ptr_head[1] = {ADDR_WIDTH{1'b0}};

      ptr_tail = {ADDR_WIDTH{1'b1}};
      //ptr_tail[1] = {ADDR_WIDTH{1'b1}};

      //swap = 1'b0;
    end else begin
      raddr = ptr_tail;
      ptr_tail = rvalid ? ptr_tail + 1'b1 : ptr_tail;
      waddr = ptr_head;
      ptr_head = wvalid ? ptr_head + 1'b1 : ptr_head;
      /*case (swap)
        1'b0: begin
          ptr_head[1] = wvalid ? ptr_head[0] + 1'b1 : ptr_head[1];
          full = ptr_head[1] == ptr_tail[1];
          ptr_tail[1] = rvalid ? ptr_tail[0] + 1'b1 : ptr_tail[1];
        end
        1'b1: begin 
          ptr_head[0] = wvalid ? ptr_head[1] + 1'b1 : ptr_head[0];
          full = ptr_head[0] == ptr_tail[0];
          ptr_tail[0] = rvalid ? ptr_tail[1] + 1'b1 : ptr_tail[0];
        end
      endcase*/
    end
  end

  //empty when both ptrs are equal
  assign empty = ptr_tail == (ptr_head - 1'b1);
  assign empty_o = empty;
  //full when head = tail - 1
  assign full = ptr_head == ptr_tail;
  assign full_o = full;

  ram_SRW # (
    .SIZE(2**ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH)
  ) ram (
    .clk(clk),
    .reset_n(reset_n),
    //.waddr_i(swap ? ptr_head[1] : ptr_head[0]),
    //.raddr_i(swap ? ptr_tail[1] : ptr_tail[0]),
    .waddr_i(waddr),
    .raddr_i(raddr),
    .wdata_i(wdata_i),
    .rdata_o(rdata_o),
    .ce_i(wvalid | rvalid),
    .we_i(wvalid)
  );

endmodule
