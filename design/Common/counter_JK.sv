module counter_JK #(
  parameter WIDTH = 3,
  parameter INC_OR_DEC = 0 //0 for increment, 1 for decrement
) (
  input  wire clk,
  input  wire reset_n,

  input  wire             set,
  input  wire [WIDTH-1:0] rst_val,
  input  wire [WIDTH-1:0] set_val,

  input  wire             trig, //triggers increment or decrement (depending on param). 

  output wire [WIDTH-1:0] q
);
  //NOTE: set J=0 K=1 for rst
  //      set J=1 K=0 for set
  //      set J=1 K=1 for alternate
  //      set J=0 K=0 for hold

  wire set_1;
  assign set_1 = reset_n & set; //if ~reset_n, set should be low, simplifies logic below

  wire [WIDTH-1:0] val_in;
  wire set_any;
  assign val_in = ~reset_n ? rst_val : set_val;
  assign set_any = (~reset_n) | set;

  wire [WIDTH:0] clk_chain; //extra bit at top is there to simplify logic below but should be ignored
  assign clk_chain[0] = clk | set_any; //all JK flip flops need to be pulsed on set
  generate for(genvar i = 0; i < WIDTH; i++) begin
    wire jkq;
    wire j, k;
    
    //assign j = ~reset_n ?  rst_val[i] : (set_1 ?  set_val[i] : 1'b1);
    //assign k = ~reset_n ? ~rst_val[i] : (set_1 ? ~set_val[i] : 1'b1);
    assign j = (~set_any) |  val_in[i];
    assign k = (~set_any) | ~val_in[i];
    ff_jk jkff (
      .clk(clk_chain[i]),
      .j(j),
      .k(k),
      .q(jkq)
    );
    assign q[i] = jkq;
    assign clk_chain[i+1] = (INC_OR_DEC ? ~jkq : jkq) | set_any;
  end endgenerate

endmodule
