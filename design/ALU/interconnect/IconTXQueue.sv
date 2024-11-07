module Icon_TXQ import exec_unit_dtypes::*; #(

) (
  input  wire clk,
  input  wire reset_n
);

  ram_queue #(
    .DATA_WIDTH($bits(type_icon_TXQentry)),
    .LOG2_SIZE(2)
  ) queue (
    .clk(clk),
    .reset_n(reset_n),
    .wvalid_i(),
    .wdata_i(),
    .rvalid_i(),
    .rready_i(),
    .rdata_o(),
    .full_o(),
    .empty_o()
  );

endmodule
