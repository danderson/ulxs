package Top;

import PinSynchronizer::*;
import Serial::*;

interface ITop;
   (* always_ready *)
   method Bit#(8) leds();
   (* always_enabled *)
   method Action uart_rx(bit v);
endinterface

module mkTop (ITop);
   // Synchronized input that's safe to read.
   Reg#(bit) rx <- mkPinSync(1);

   let uart <- mkSerialReceiver(25_000_000, 115200);
   rule pump_uart;
      uart.rx(rx);
   endrule

   Reg#(Bit#(8)) leds_val <- mkReg(0);
   rule update_leds;
      leds_val <= uart;
   endrule

   method leds = leds_val._read;
   method uart_rx = rx._write;
endmodule

endpackage
