package TB;

import Assert::*;
import StmtFSM::*;

import Strobe::*;
import PinSynchronizer::*;
import Serial::*;

module mkTB ();
   Reg#(UInt#(32)) cycles <- mkReg(0);
   rule timeout;
      cycles <= cycles+1;
      dynamicAssert(cycles <= 100000, "test timeout");
   endrule

   let strobe <- testStrobe();
   let sync <- testPinSync();
   let serialRX <- testSerialReceiver();

   function RStmt#(Bit#(0)) run(String name, FSM test);
      return seq
                test.start();
                test.waitTillDone();
                $display("OK ", name);
             endseq;
   endfunction
   mkAutoFSM(par
                run("testStrobe", strobe);
                run("testPinSync", sync);
                run("testSerialReceiver", serialRX);
             endpar);
endmodule

module testStrobe (FSM);
   Reg#(UInt#(32)) cycles <- mkReg(0);
   rule count_cycles;
      cycles <= cycles+1;
   endrule

   let raw <- mkStrobeRaw(8, 53);
   Reg#(UInt#(32)) raw_strobes <- mkReg(0);
   rule count_raw (raw);
      raw_strobes <= raw_strobes+1;
   endrule

   let cooked <- mkStrobe(100, 23);
   Reg#(UInt#(32)) cooked_strobes <- mkReg(0);
   rule count_cooked (cooked);
      cooked_strobes <= cooked_strobes+1;
   endrule

   let fsm <- mkFSM(seq
                       await(cycles == 255);
                       dynamicAssert(raw_strobes == 53, "wrong number of raw strobes");
                       await(cycles == 1000);
                       dynamicAssert(cooked_strobes == 230, "wrong number of cooked strobes");
                    endseq);
   return fsm;
endmodule

module testPinSync (FSM);
   let s <- mkPinSync(0);

   let fsm <- mkFSM(seq
                       s <= 1;
                       dynamicAssert(s == 0, "synchronizer didn't synchronize");
                       dynamicAssert(s == 1, "synchronizer too slow");
                       s <= 0;
                       dynamicAssert(s == 1, "synchronizer didn't synchronize");
                       dynamicAssert(s == 0, "synchronizer too slow");
                    endseq);
   return fsm;
endmodule

module testSerialReceiver (FSM);
   let timer <- mkStrobe(200, 7);
   let r <- mkSerialReceiver(200, 7);
   Reg#(bit) rx <- mkReg(1);
   rule rx_pump;
      r.rx(rx);
   endrule

   let write_test = seq
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
   let write_fsm <- mkFSMWithPred(write_test, timer);

   let test = par
                 seq
                    write_fsm.start();
                    write_fsm.waitTillDone();
                 endseq
                 seq
                    action
                       let b = r;
                       let want = 8'b10110111;
                       dynamicAssert(b == want, "wrong byte received");
                    endaction
                 endseq
              endpar;
   let fsm <- mkFSM(test);
   return fsm;
endmodule

endpackage
