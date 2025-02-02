`include "simulation_parameters.sv"

module cache_DP # ( //must read protected cache
  //Xilinx supports dual port ram blocks. Obviously comes with an area
  //impact compared to single port but this ram module is not tailored for large storage capacity
  //so area penalty can be accepted
  //https://docs.amd.com/r/2022.1-English/ug1483-model-composer-sys-gen-user-guide/Dual-Port-RAM

  //NUM_ENTRIES will equal 2**IDX_BITS
  //avoids having to have extra logic for out of
  //bound address checks
  parameter IDX_BITS = 2,

  parameter DATA_WIDTH = 16,
  parameter ADDR_WIDTH = 8
) (
  input  wire                   clk,
  input  wire                   reset_n,

  input  wire  [ADDR_WIDTH-1:0] addra_i,
  input  wire  [ADDR_WIDTH-1:0] addrb_i,

  input  wire  [DATA_WIDTH-1:0] wdata_i,

  input  wire                   cea_i,
  input  wire                   ceb_i,
  input  wire                   we_i,

  output logic [DATA_WIDTH-1:0] rdataa_o,
  output logic [DATA_WIDTH-1:0] rdatab_o,
  //if tag address does not match on read, then read is invalid
  output logic                  rhita_o,
  output logic                  rhitb_o
);

  localparam TAG_ADDRESS_WITDH = ADDR_WIDTH - IDX_BITS;

  typedef struct packed {
    logic        [DATA_WIDTH-1:0] data;
    logic [TAG_ADDRESS_WITDH-1:0] stored_tag;
  } cache_entry;

  cache_entry rdataa;
  cache_entry rdatab;
  cache_entry wdata;

  assign rhita_o  = rdataa.stored_tag == addra_i[ADDR_WIDTH-1:IDX_BITS];//&(~(rdataa.stored_tag ^ addra_i[ADDR_WIDTH-1:IDX_BITS]));
  assign rhitb_o  = rdatab.stored_tag == addrb_i[ADDR_WIDTH-1:IDX_BITS];//&(~(rdatab.stored_tag ^ addrb_i[ADDR_WIDTH-1:IDX_BITS]));
  assign rdataa_o = rdataa.data;
  assign rdatab_o = rdatab.data;

  assign wdata.data       = wdata_i;
  assign wdata.stored_tag = addra_i[ADDR_WIDTH-1:IDX_BITS];

  //ram instance
  xpm_memory_dpdistram #(
      .ADDR_WIDTH_A(IDX_BITS),
      .ADDR_WIDTH_B(IDX_BITS),
      .BYTE_WRITE_WIDTH_A($bits(cache_entry)),
      .CLOCKING_MODE("common_clock"),
      .IGNORE_INIT_SYNTH(0),
      .MEMORY_INIT_FILE("none"),
      .MEMORY_INIT_PARAM("0"),
      .MEMORY_OPTIMIZATION("true"),
      .MEMORY_SIZE((2**IDX_BITS)*$bits(cache_entry)),
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
      .douta(rdataa),   // READ_DATA_WIDTH_A-bit output: Data output for port A read operations.
      .doutb(rdatab),   // READ_DATA_WIDTH_B-bit output: Data output for port B read operations.
      .addra(addra_i[IDX_BITS-1:0]),   // ADDR_WIDTH_A-bit input: Address for port A write and read operations.
      .addrb(addrb_i[IDX_BITS-1:0]),   // ADDR_WIDTH_B-bit input: Address for port B write and read operations.
      .clka(clk),     // 1-bit input: Clock signal for port A. Also clocks port B when parameter CLOCKING_MODE
                       // is "common_clock".

      .clkb(1'b0),     // 1-bit input: Clock signal for port B when parameter CLOCKING_MODE is
                       // "independent_clock". Unused when parameter CLOCKING_MODE is "common_clock".

      .dina(wdata),     // WRITE_DATA_WIDTH_A-bit input: Data input for port A write operations.
      .ena(cea_i),       // 1-bit input: Memory enable signal for port A. Must be high on clock cycles when read
                       // or write operations are initiated. Pipelined internally.

      .enb(ceb_i),       // 1-bit input: Memory enable signal for port B. Must be high on clock cycles when read
                       // or write operations are initiated. Pipelined internally.

      .regcea(1'b1), // 1-bit input: Clock Enable for the last register stage on the output data path.
      .regceb(1'b1), // 1-bit input: Do not change from the provided value.
      .rsta(reset_n),     // 1-bit input: Reset signal for the final port A output register stage. Synchronously
                       // resets output port douta to the value specified by parameter READ_RESET_VALUE_A.

      .rstb(reset_n),     // 1-bit input: Reset signal for the final port B output register stage. Synchronously
                       // resets output port doutb to the value specified by parameter READ_RESET_VALUE_B.

      .wea(we_i)        // WRITE_DATA_WIDTH_A/BYTE_WRITE_WIDTH_A-bit input: Write enable vector for port A input
                       // data port dina. 1 bit wide when word-wide writes are used. In byte-wide write
                       // configurations, each bit controls the writing one byte of dina to address addra. For
                       // example, to synchronously write only bits [15-8] of dina when WRITE_DATA_WIDTH_A is
                       // 32, wea would be 4'b0010.

   );

  /*typedef struct packed {
    logic        [DATA_WIDTH-1:0] data;
    logic [TAG_ADDRESS_WITDH-1:0] stored_tag;
  } cache_entry;

  logic [(2**IDX_BITS)-1:0] has_been_read;
  //(* ram_style = "block" *) cache_entry ram [(2**IDX_BITS)-1:0];
  logic [(2**IDX_BITS)-1:0] [(DATA_WIDTH+TAG_ADDRESS_WITDH)-1:0] ram;

  wire [IDX_BITS-1:0] idx;
  assign idx = addr_i[IDX_BITS-1:0];

  always_ff @(posedge clk or negedge reset_n) begin
    if (~reset_n) begin
      ram = '0;
    end else if (ce_i) begin
      if (we_i) begin
        if (has_been_read[idx]) begin
          //ram[idx].data          <= wdata_i;
          //ram[idx].stored_tag    <= addr_i[ADDR_WIDTH-1:IDX_BITS];
          ram[idx]               = {addr_i[ADDR_WIDTH-1:IDX_BITS], wdata_i};
          has_been_read[idx]     = 1'b0;
          
          wack_o                 = 1'b1;
        end else begin
          wack_o                 = 1'b0;
        end
      end else begin
        //rdata_o          <= ram[idx].data;
        //rhit_o           <= ram[idx].stored_tag == addr_i[ADDR_WIDTH-1:IDX_BITS];
        rhit_o             = ram[idx][(DATA_WIDTH+TAG_ADDRESS_WITDH)-1:DATA_WIDTH] == addr_i[ADDR_WIDTH-1:IDX_BITS];
        rdata_o            = rhit_o ? ram[idx][DATA_WIDTH-1:0] : '0;
        has_been_read[idx] = rhit_o;
      end
    end
  end*/
endmodule
