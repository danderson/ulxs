// A debouncer takes an asynchronous bouncy input, and outputs a
// debounced version of the input.
module debouncer(input clk, input btn, output out);
   reg [1:0] sync;
   always @(posedge clk) sync <= {sync[0], btn};

   reg [7:0] cnt;
   always @(posedge clk) begin
	  if (sync[1] == 0) begin
		 cnt <= 0;
	  end else if (cnt != 8'hFF) begin
		 cnt <= cnt + 1;
	  end
   end
   assign out = cnt[7];
endmodule
