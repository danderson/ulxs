package Top;

import PinSynchronizer::*;
import Serial::*;

interface ITop;
   (* always_ready *)
   method Bit#(8) leds();
   (* always_enabled *)
   method Action uart_rx(bit v);
   (* always_ready *)
   method bit uart_tx();
endinterface

module mkTop (ITop);
   // Synchronized input that's safe to read.
   Reg#(bit) rx <- mkPinSync(1);

   let receiver <- mkSerialReceiver(25_000_000, 115200);
   rule pump_receiver;
      receiver.rx(rx);
   endrule

   Reg#(bit) tx_bit <- mkReg(1);
   let transmitter <- mkSerialTransmitter(25_000_000, 115200);
   rule pump_transmitter;
      tx_bit <= transmitter.tx();
   endrule

   Reg#(Bit#(8)) leds_val <- mkReg(0);
   rule update_leds;
      transmitter <= receiver;
      leds_val <= receiver;
   endrule

   method leds = leds_val._read;
   method uart_rx = rx._write;
   method uart_tx = tx_bit._read;
endmodule

endpackage
