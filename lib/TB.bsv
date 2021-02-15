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

endpackage
