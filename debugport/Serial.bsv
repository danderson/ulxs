package Serial;

import Cntrs::*;
import Strobe::*;
import StmtFSM::*;

interface IUART;
   (* always_enabled *)
   method Action rx(bit v);
   method Bit#(8) _read();
endinterface

module mkSerialReceiver #(Integer clk_freq, Real baud_rate) (IUART);
   // Strobes at 16x the desired baud rate, so we can find the start
   // of bit.
   let rx_sense <- mkStrobe(clk_freq, baud_rate*16);

   // middle-of-bit finder. Gets reset when we detect the start bit,
   // then fires a strobe in the middle of bits from then on.
   UCount bit_sync <- mkUCount(0, 15);
   PulseWire middle_of_bit <- mkPulseWire();
   (* fire_when_enabled, no_implicit_conditions *)
   rule generate_middle_of_bit (rx_sense);
      bit_sync.incr(1);
      if (bit_sync.isEqual(8)) middle_of_bit.send();
   endrule

   // The bit reader state machine. Once triggered, reads a byte into
   // shift.
   Wire#(bit) rx_bit <- mkWire();
   Reg#(Bit#(8)) shift <- mkReg(0);
   let read_byte = seq
                      noAction; // discard start bit
                      repeat (8) shift <= {rx_bit, shift[7:1]};
                      noAction; // discard stop bit
                   endseq;
   let reader <- mkFSMWithPred(read_byte, middle_of_bit);

   (* fire_when_enabled *)
   rule start_read (reader.done() && rx_sense && rx_bit == 0);
      bit_sync <= 0;
      reader.start();
   endrule

   // Finally, the methods. One to push bits from the wire into the
   // UART, the other to read out bytes when they're available.
   method rx = rx_bit._write;
   method Bit#(8) _read() if (reader.done());
      return shift;
   endmethod
endmodule

endpackage
