module debugport(input clk_25mhz,
				 input ftdi_txd,
				 input [1:0] btn,
				 output reg [7:0] led,
				 output wifi_gpio0);
   wire [7:0] uart_byte;
   wire uart_ready;
   // input 25000000Hz, output 9600Hz, 16x oversample, error 0.33%
   uart #(.baud_acc_width(14), .baud_acc_incr(101))
     uart(.i_clk(clk_25mhz), .i_rx(ftdi_txd), .o_byte(uart_byte), .o_ready(uart_ready));

   // Only display a byte when it's been completely read-in.
   always @(posedge clk_25mhz) begin
	  if (~btn[0] || btn[1]) led <= 0;
	  else if (uart_ready) led <= uart_byte;
   end
   assign wifi_gpio0 = 1'b1;
endmodule
