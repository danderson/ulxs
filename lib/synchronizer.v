module synchronizer(input clk, input in, output out);
   reg [1:0] sync;
   always @(posedge clk) sync <= {sync[0], in};
   assign out = sync[1];
endmodule
