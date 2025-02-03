`include "simulation_parameters.sv"

module fifo_buffer # (
  parameter LOG2_QUEUE_LENGTH = 2,
  parameter DATA_WIDTH = 16,
  localparam ADDR_WIDTH = LOG2_QUEUE_LENGTH
) (
  input  wire                   clk,
  input  wire                   reset_n,

  input  wire  [DATA_WIDTH-1:0] wdata_i,
  input  wire                   wvalid_i,

  output logic [DATA_WIDTH-1:0] rdata_o,
  input  logic                  rready_i,

  output wire                   full_o,
  output wire                   empty_o
);

  wire wvalid;
  wire rvalid;

  logic [ADDR_WIDTH-1:0] waddr;
  logic [ADDR_WIDTH-1:0] raddr;

  logic [ADDR_WIDTH-1:0] ptr_head;
  logic [ADDR_WIDTH-1:0] ptr_tail;
  logic full;
  wire  empty;

  assign wvalid = wvalid_i & ~full;
  assign rvalid = rready_i & ~empty;
  always_ff @(posedge clk) begin: ff_ptrs
    if(~reset_n) begin
      ptr_head = {ADDR_WIDTH{1'b0}};
      ptr_tail = {ADDR_WIDTH{1'b1}};
    end else begin
      raddr = ptr_tail;
      ptr_tail = rvalid ? ptr_tail + 1'b1 : ptr_tail;
      waddr = ptr_head;
      ptr_head = wvalid ? ptr_head + 1'b1 : ptr_head;
    end
  end

  //empty when both ptrs are equal
  assign empty = ptr_tail == (ptr_head - 1'b1);
  assign empty_o = empty;
  //full when head = tail - 1
  assign full = ptr_head == ptr_tail;
  assign full_o = full;

  //ram instance
  xpm_memory_dpdistram #(
      .ADDR_WIDTH_A(ADDR_WIDTH),
      .ADDR_WIDTH_B(ADDR_WIDTH),
      .BYTE_WRITE_WIDTH_A($bits(cache_entry)),
      .CLOCKING_MODE("common_clock"),
      .IGNORE_INIT_SYNTH(0),
      .MEMORY_INIT_FILE("none"),
      .MEMORY_INIT_PARAM("0"),
      .MEMORY_OPTIMIZATION("true"),
      .MEMORY_SIZE((2**LOG2_QUEUE_LENGTH)*DATA_WIDTH),
      .MESSAGE_CONTROL(`MODE_SIM),
      .READ_DATA_WIDTH_A($bits(cache_entry)),
      .READ_DATA_WIDTH_B($bits(cache_entry)),
      .READ_LATENCY_A(0),
      .READ_LATENCY_B(0),
      .READ_RESET_VALUE_A("0"),
      .READ_RESET_VALUE_B("0"),
      .RST_MODE_A("SYNC"),
      .RST_MODE_B("SYNC"),
      .SIM_ASSERT_CHK(`MODE_SIM),
      .USE_EMBEDDED_CONSTRAINT(0),
      .USE_MEM_INIT(1),
      .USE_MEM_INIT_MMI(0),
      .WRITE_DATA_WIDTH_A($bits(cache_entry))
   )
   xpm_memory_dpdistram_inst (
      .douta(),   // READ_DATA_WIDTH_A-bit output: Data output for port A read operations.
      .doutb(rdata_o),   // READ_DATA_WIDTH_B-bit output: Data output for port B read operations.
      .addra(waddr),   // ADDR_WIDTH_A-bit input: Address for port A write and read operations.
      .addrb(raddr),   // ADDR_WIDTH_B-bit input: Address for port B write and read operations.
      .clka(clk),     // 1-bit input: Clock signal for port A. Also clocks port B when parameter CLOCKING_MODE
                       // is "common_clock".

      .clkb(1'b0),     // 1-bit input: Clock signal for port B when parameter CLOCKING_MODE is
                       // "independent_clock". Unused when parameter CLOCKING_MODE is "common_clock".

      .dina(wdata_i),     // WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
      .ena(wvalid_i),       // 1-bit input: Memory enable signal for port A. Must be high on clock cycles when read
                       // or write operations are initiated. Pipelined internally.

      .enb(rready_i),       // 1-bit input: Memory enable signal for port B. Must be high on clock cycles when read
                       // or write operations are initiated. Pipelined internally.

      .regcea(1'b1), // 1-bit input: Clock Enable for the last register stage on the output data path.
      .regceb(1'b1), // 1-bit input: Do not change from the provided value.
      .rsta(reset_n),     // 1-bit input: Reset signal for the final port A output register stage. Synchronously
                       // resets output port douta to the value specified by parameter READ_RESET_VALUE_A.

      .rstb(reset_n),     // 1-bit input: Reset signal for the final port B output register stage. Synchronously
                       // resets output port doutb to the value specified by parameter READ_RESET_VALUE_B.

      .wea(1'b1)        // WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A-bit input: Write enable vector for port A input
                       // data port dina. 1 bit wide when word-wide writes are used. In byte-wide write
                       // configurations, each bit controls the writing one byte of dina to address addra. For
                       // example, to synchronously write only bits [15-8] of dina when WRITE_DATA_WIDTH_A is
                       // 32, wea would be 4'b0010.

   );
endmodule
