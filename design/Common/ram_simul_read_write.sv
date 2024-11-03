
`include "simulation_parameters.sv"

module ram_SRW # ( //simultaneous read write
  parameter SIZE = 16,
  parameter DATA_WIDTH = 16,
  parameter ADDR_WIDTH = 8
) (
  input  wire                   clk,
  input  wire                   reset_n,

  input  wire  [ADDR_WIDTH-1:0] waddr_i,
  input  wire  [ADDR_WIDTH-1:0] raddr_i,

  input  wire  [DATA_WIDTH-1:0] wdata_i,

  input  wire                   ce_i,
  input  wire                   we_i,

  output logic [DATA_WIDTH-1:0] rdata_o
);

  typedef struct packed {
    logic [DATA_WIDTH-1:0] data;
  } ram_entry;

  ram_entry rdata;
  ram_entry wdata;
  assign rdata_o    = rdata.data;
  assign wdata.data = wdata_i;

  //ram instance
  xpm_memory_dpdistram #(
      .ADDR_WIDTH_A(ADDR_WIDTH),
      .ADDR_WIDTH_B(ADDR_WIDTH),
      .BYTE_WRITE_WIDTH_A($bits(ram_entry)),
      .CLOCKING_MODE("common_clock"),
      .IGNORE_INIT_SYNTH(0),
      .MEMORY_INIT_FILE("none"),
      .MEMORY_INIT_PARAM("0"),
      .MEMORY_OPTIMIZATION("true"),
      .MEMORY_SIZE(SIZE*DATA_WIDTH),
      .MESSAGE_CONTROL(`MODE_SIM),
      .READ_DATA_WIDTH_A($bits(ram_entry)),
      .READ_DATA_WIDTH_B($bits(ram_entry)),
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
      .WRITE_DATA_WIDTH_A($bits(ram_entry))
  ) xpm_memory_dpdistram_inst (
    .douta(),   // READ_DATA_WIDTH_A-bit output: Data output for port A read operations.
    .doutb(rdata),   // READ_DATA_WIDTH_B-bit output: Data output for port B read operations.
    .addra(waddr_i),   // ADDR_WIDTH_A-bit input: Address for port A write and read operations.
    .addrb(raddr_i),   // ADDR_WIDTH_B-bit input: Address for port B write and read operations.
    .clka(clk),     // 1-bit input: Clock signal for port A. Also clocks port B when parameter CLOCKING_MODE
                      // is "common_clock".

    .clkb(1'b0),     // 1-bit input: Clock signal for port B when parameter CLOCKING_MODE is
                      // "independent_clock". Unused when parameter CLOCKING_MODE is "common_clock".

    .dina(wdata),     // WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
    .ena(we_i),       // 1-bit input: Memory enable signal for port A. Must be high on clock cycles when read
                      // or write operations are initiated. Pipelined internally.

    .enb(ce_i),       // 1-bit input: Memory enable signal for port B. Must be high on clock cycles when read
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
