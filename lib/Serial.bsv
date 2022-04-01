package Serial;

import Cntrs::*;
import GetPut::*;
import Strobe::*;
import StmtFSM::*;

interface SerialReceiver;
   interface Put#(bit) bit_in;
   interface Get#(Bit#(8)) byte_out;
endinterface

module mkSerialReceiver #(Integer clk_freq, Real baud_rate) (SerialReceiver);
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
   Wire#(Bit#(8)) finished_byte <- mkWire();
   let read_byte = seq
                      noAction; // discard start bit
                      repeat (8) shift <= {rx_bit, shift[7:1]};
                      finished_byte <= shift; // discard stop bit, yield result.
                   endseq;
   let reader <- mkFSMWithPred(read_byte, middle_of_bit);

   (* fire_when_enabled *)
   rule start_read (reader.done() && rx_sense && rx_bit == 0);
      bit_sync <= 0;
      reader.start();
   endrule

   // Finally, the methods. One to push bits from the wire into the
   // UART, the other to read out bytes when they're available.
   interface Get byte_out;
      method ActionValue#(Bit#(8)) get;
         return finished_byte;
      endmethod
   endinterface
   interface Put bit_in;
      method put = rx_bit._write;
   endinterface
endmodule

interface SerialTransmitter;
   interface Put#(Bit#(8)) byte_in;
   interface Get#(bit) bit_out;
endinterface

module mkSerialTransmitter #(Integer clk_freq, Real baud_rate) (SerialTransmitter);
   let tx_timing <- mkStrobe(clk_freq, baud_rate);

   Reg#(Bit#(8)) shift <- mkReg(0);
   Wire#(bit) tx_bit <- mkWire();
   let write_byte = seq
                       tx_bit <= 0; // start bit
                       repeat (8) action
                                     tx_bit <= shift[0];
                                     shift <= shift>>1;
                                  endaction
                       tx_bit <= 1; // stop bit
                    endseq;
   let writer <- mkFSMWithPred(write_byte, tx_timing);

   interface Put byte_in;
      method Action put(Bit#(8) b) if (writer.done());
         shift <= b;
         writer.start();
      endmethod
   endinterface
   interface Get bit_out;
      method ActionValue#(bit) get;
         return tx_bit._read;
      endmethod
   endinterface
endmodule

endpackage
