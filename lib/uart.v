module uart (input i_clk,

			 // Receiver
			 input i_rx,
			 output reg [7:0] o_rx_byte,
			 output reg o_rx_ready
			 );
   parameter baud_acc_width=1, baud_acc_incr=2;

   //
   // Receiver
   //

   // Generate a pulse 16 times faster than the desired baud rate.
   wire baud_x16;
   pulse_gen #(.acc_width(baud_acc_width), .acc_incr(baud_acc_incr))
     baud_gen(.i_clk, .o_pulse(baud_x16));

   // Synchronize i_rx into rx_sync.
   reg 	rx_sync, rx_buf;
   always @(posedge i_clk) begin
	  rx_buf <= i_rx;
	  rx_sync <= rx_buf;
   end

   // Debounce rx_sync into rx. Signal must be stable for 3 samples
   // before rx changes.
   reg [1:0] rx_debounce;
   reg rx_bit;
   always @(posedge i_clk) begin
	  if (baud_x16) begin
		 if (rx_sync == 1 && rx_debounce != 2'b11) rx_debounce <= rx_debounce + 1;
		 else if (rx_sync == 0 && rx_debounce != 2'b00) rx_debounce <= rx_debounce - 1;

		 if (rx_debounce == 2'b11) rx_bit <= 1;
		 else if (rx_debounce == 2'b00) rx_bit <= 0;
	  end
   end

   // Bit reading state machine.
   //reg [3:0] rx_state; // 11 states: idle, 1 start bit, 8 bits, 1 stop.
   enum {IDLE, START, STOP, B1=8, B2, B3, B4, B5, B6, B7, B8} rx_state;
   wire rx_sample;
   always @(posedge i_clk) begin
	  case (rx_state)
		// Idle, waiting for start of start bit.
		IDLE: if (rx_bit == 0) rx_state <= START;
		// Wait for start bit to happen.
		START: if (rx_sample) rx_state <= B1;
		// Read 8 data bits.
		B1: if (rx_sample) rx_state <= B2;
		B2: if (rx_sample) rx_state <= B3;
		B3: if (rx_sample) rx_state <= B4;
		B4: if (rx_sample) rx_state <= B5;
		B5: if (rx_sample) rx_state <= B6;
		B6: if (rx_sample) rx_state <= B7;
		B7: if (rx_sample) rx_state <= B8;
		B8: if (rx_sample) rx_state <= STOP;
		// One stop bit.
		STOP: if (rx_sample) rx_state <= IDLE;
		default: rx_state <= IDLE;
	  endcase
   end // always @ (posedge i_clk)

   // Generate the rx_sample signal. When the state machine leaves
   // state 0, start counting and generate pulses in the middle of
   // bits.
   reg [3:0] rx_middle_cnt;
   always @(posedge i_clk) begin
	  if (baud_x16) begin
		 if (rx_state == 0) rx_middle_cnt <= 4'b0111;
		 else rx_middle_cnt <= rx_middle_cnt + 1;
	  end
   end
   assign rx_sample = baud_x16 && (rx_middle_cnt == 4'b1111);

   // Finally, read data bits into a shift register. We arranged the
   // state machine numeric values such that rx_state[3] is handily
   // "data bit is being read".
   wire rx_data_bit = rx_state[3];
   always @(posedge i_clk) begin
	  if (rx_sample && rx_data_bit) o_rx_byte <= {rx_bit, o_rx_byte[7:1]};

	  // And finally, generate the "output ready" bit once we've received
	  // the stop bit. Note we ignore the value of the stop bit, since
	  // accounting for bad framing would require even more interface,
	  // and I don't feel clever enough for that yet.
	  o_rx_ready <= rx_sample && rx_state == STOP;
   end
endmodule
