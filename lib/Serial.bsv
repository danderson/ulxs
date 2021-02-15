package Serial;

import Cntrs::*;
import Strobe::*;
import StmtFSM::*;

interface ISerialReceiver;
   (* always_enabled *)
   method Action rx(bit v);
   method Bit#(8) _read();
endinterface

module mkSerialReceiver #(Integer clk_freq, Real baud_rate) (ISerialReceiver);
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
   Wire#(Bit#(8)) out <- mkWire();
   let read_byte = seq
                      noAction; // discard start bit
                      repeat (8) shift <= {rx_bit, shift[7:1]};
                      out <= shift; // discard stop bit, yield result.
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
   method _read = out._read;
endmodule

interface ISerialTransmitter;
   method Action _write(Bit#(8) b);
   method bit tx();
endinterface

module mkSerialTransmitter #(Integer clk_freq, Real baud_rate) (ISerialTransmitter);
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

   method tx = tx_bit._read;
   method Action _write(Bit#(8) b) if (writer.done());
      shift <= b;
      writer.start();
   endmethod
endmodule

endpackage
