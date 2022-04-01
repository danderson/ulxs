package Top;

import Connectable::*;
import GetPut::*;

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
   Reg#(bit) rx_bit <- mkPinSync(1);
   let receiver <- mkSerialReceiver(25_000_000, 115200);
   mkConnection(toGet(asIfc(rx_bit)), receiver.bit_in);

   Reg#(bit) tx_bit <- mkReg(1);
   let transmitter <- mkSerialTransmitter(25_000_000, 115200);
   mkConnection(transmitter.bit_out, toPut(asReg(tx_bit)));

   function Bit#(8) rot13(Bit#(8) v);
      UInt#(8) i = unpack(v);
      if (i >= 65 && i <= 90)
         return pack(((i-65+13)%26)+65);
      else if (i >= 97 && i <= 122)
         return pack(((i-97+13)%26)+97);
      else
         return v;
   endfunction

   Reg#(Bit#(8)) leds_val <- mkReg(0);
   rule update_leds;
      let v <- receiver.byte_out.get();
      leds_val <= v;
      let char = rot13(v);
      transmitter.byte_in.put(char);
   endrule

   method leds = leds_val._read;
   method uart_rx = rx_bit._write;
   method uart_tx = tx_bit._read;
endmodule

endpackage
