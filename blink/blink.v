// Blinkenlights program. Mostly exists to verify that the toolchain
// is correct, but also serves as a handy introduction to input
// synchronization and debouncing.

// A debouncer takes an asynchronous bouncy input, and outputs a
// debounced version of the input.
module debouncer(input clk, input btn, output out);
   reg [1:0] sync;
   always @(posedge clk) sync <= {sync[0], btn};

   reg [8:0] cnt;
   always @(posedge clk) begin
	  if (sync[1] == 0) begin
		 cnt <= 0;
	  end else if (cnt != 8'hFF) begin
		 cnt <= cnt + 1;
	  end
   end
   assign out = cnt[7];
endmodule

// The main event. Takes in a couple of buttons, and drives the LED
// bank in a pleasing diagnostic-ish pattern.
//
// Button F1 lights up the left-most LED when held.
//
// Button F2 allows the LED counter to increment when held, such that
// the LEDs will count up in binary. Releasing F2 will pause the
// counter, freezing the LED output.
//
// Button UP resets the counter to zero, which clears the counting
// LEDs.
module blink(input clk_25mhz, input [3:0] btn,
			 output reg [7:0] led, output wifi_gpio0);
   // Tell ESP32 we're alive, so it doesn't reboot and take control of
   // the board. btn[0] is the "PWR" button on the board, and is
   // active low. So, we can wire it directly to the keepalive signal,
   // and pressing the button will disable the keepalive.
   assign wifi_gpio0 = btn[0];

   wire btn_reset;
   debouncer btn_reset_db(.clk (clk_25mhz), .btn (btn[3]), .out (btn_reset));

   wire btn_incr;
   debouncer btn_incr_db(.clk (clk_25mhz), .btn (btn[2]), .out (btn_incr));

   reg [31:0] ctr = 32'hFFFFFFFF;

   always @(posedge clk_25mhz) begin
	  if (btn_reset == 1'b1) begin
		 ctr <= 0;
	  end
	  if (btn_incr == 1'b1) begin
		 ctr <= ctr + 1;
	  end
	  led[7] <= btn[1];
	  led[6:0] <= ctr[28:22];
   end
endmodule
