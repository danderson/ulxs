package Top;

import Cntrs::*;
import BRAM::*;
import Connectable::*;
import GetPut::*;
import StmtFSM::*;

import PinSynchronizer::*;
import Serial::*;
import Strobe::*;

interface ITop;
   (* always_ready *)
   method Bit#(8) leds();
   (* always_enabled *)
   method Action uart_rx(bit v);
   (* always_ready *)
   method bit uart_tx();
endinterface

module mkTop (ITop);
   Reg#(bit) rx <- mkPinSync(1);
   let receiver <- mkSerialReceiver(25_000_000, 115200);
   mkConnection(toGet(asReg(rx)), receiver.bit_in);

   Reg#(bit) tx_bit <- mkReg(1);
   let transmitter <- mkSerialTransmitter(25_000_000, 115200);
   mkConnection(transmitter.bit_out, toPut(asReg(tx_bit)));

   let cfg = BRAM_Configure{
      memorySize: 256,
      latency: 1,
      outFIFODepth: 3,
      loadFormat: tagged Hex "mem.hex",
      allowWriteResponseBypass: False
   };
   BRAM1Port#(Bit#(8), Bit#(8)) ram <- mkBRAM1Server(cfg);
   Reg#(Bool) is_write <- mkRegU();
   Reg#(Bit#(8)) r_addr <- mkRegU();
   Reg#(Bit#(8)) r_val <- mkRegU();
   function Bit#(4) addrNibble(Bit#(8) b);
      if (b >= 48 && b <= 57)
         return truncate(b-48);
      else if (b >= 97 && b <= 102)
         return truncate(b-97+10);
      else
         return 0;
   endfunction
   let process_request = seq
                            action
                               let v <- receiver.byte_out.get();
                               is_write <= (v == 119);
                            endaction
                            if (is_write)
                               transmitter.byte_in.put(87);
                            else
                               transmitter.byte_in.put(82);
                            transmitter.byte_in.put(32);
                            action
                               let v <- receiver.byte_out.get();
                               r_addr <= zeroExtend(addrNibble(v))<<4;
                               transmitter.byte_in.put(v);
                            endaction
                            action
                               let v <- receiver.byte_out.get();
                               r_addr <= {r_addr[7:4], addrNibble(v)};
                               transmitter.byte_in.put(v);
                            endaction
                            transmitter.byte_in.put(32);
                            if (is_write)
                               seq
                                  action
                                     let v <- receiver.byte_out.get();
                                     transmitter.byte_in.put(v);
                                     r_val <= v;
                                  endaction
                                  ram.portA.request.put(BRAMRequest{
                                     write: True,
                                     responseOnWrite: False,
                                     address: r_addr,
                                     datain: r_val
                                     });
                               endseq
                            else
                               seq
                                  ram.portA.request.put(BRAMRequest{
                                     write: False,
                                     responseOnWrite: False,
                                     address: r_addr,
                                     datain: ?
                                  });
                                  action
                                     let v <- ram.portA.response.get();
                                     transmitter.byte_in.put(v);
                                  endaction
                               endseq
                            transmitter.byte_in.put(13);
                            transmitter.byte_in.put(10);
                         endseq;
   let processor <- mkFSM(process_request);
   rule write_to_ram (processor.done);
      processor.start();
   endrule

   // Reg#(Bit#(8)) led_value <- mkReg(0);
   // Count#(UInt#(4)) addr <- mkCount(0);
   // let onceASecond <- mkStrobe(25_000_000, 4);
   // let mem_to_leds = seq
   //                      ram.portB.request.put(BRAMRequest{
   //                         write: False,
   //                         responseOnWrite: False,
   //                         address: zeroExtend(addr),
   //                         datain: 0
   //                      });
   //                      action
   //                         let v <- ram.portB.response.get();
   //                         led_value <= v;
   //                      endaction
   //                   endseq;
   // let memToLeder <- mkFSM(mem_to_leds);
   // rule read_from_ram (memToLeder.done && onceASecond);
   //    addr.incr(1);
   //    memToLeder.start();
   // endrule

   method Bit#(8) leds;
      return 0;
   endmethod

   method uart_rx = rx._write;
   method uart_tx = tx_bit._read;
endmodule

endpackage
