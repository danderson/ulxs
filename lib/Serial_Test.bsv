package Serial_Test;

import Assert::*;
import Connectable::*;
import GetPut::*;
import StmtFSM::*;

import Serial::*;
import Strobe::*;
import Testing::*;

module mkTB();
   let rx_test <- mkReceiveTest();
   let tx_test <- mkTransmitTest();

   mkTest("Serial", seq
      $display("  Receiver");
      rx_test.start();
      rx_test.waitTillDone();
      $display("  Transmitter");
      tx_test.start();
      tx_test.waitTillDone();
   endseq);
endmodule

module mkReceiveTest(FSM);
   let timer <- mkStrobe(200, 7);
   let r <- mkSerialReceiver(200, 7);
   Reg#(bit) rx <- mkReg(1);
   mkConnection(toGet(asReg(rx)), r.bit_in);

   let writer = seq
                   rx <= 1;
                   rx <= 0; // start
                   rx <= 1;
                   rx <= 1;
                   rx <= 1;
                   rx <= 0;
                   rx <= 1;
                   rx <= 1;
                   rx <= 0;
                   rx <= 1;
                   rx <= 1; // stop
                endseq;
   let write_fsm <- mkFSMWithPred(writer, timer);

   let test <- mkFSM(par
                        seq
                           write_fsm.start();
                           write_fsm.waitTillDone();
                        endseq
                        seq
                           action
                              let b <- r.byte_out.get();
                              let want = 8'b10110111;
                              dynamicAssert(b == want, "wrong byte received");
                           endaction
                        endseq
                     endpar);
   return test;
endmodule

module mkTransmitTest(FSM);
   let t <- mkSerialTransmitter(200, 7);
   Reg#(bit) b <- mkReg(1);
   let r <- mkSerialReceiver(200, 7);
   mkConnection(t.bit_out, toPut(asReg(b)));
   mkConnection(toGet(asReg(b)), r.bit_in);

   let want = 8'b10110011;
   let test = seq
                 t.byte_in.put(want);
                 action
                    let got <- r.byte_out.get();
                    dynamicAssert(got == want, "wrong byte received");
                 endaction
              endseq;
   let fsm <- mkFSM(test);
   return fsm;
endmodule

endpackage
