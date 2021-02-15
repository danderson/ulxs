package TB;

import Assert::*;
import StmtFSM::*;

import Strobe::*;
import PinSynchronizer::*;

module mkTB ();
   Reg#(UInt#(32)) cycles <- mkReg(0);
   rule timeout;
      cycles <= cycles+1;
      dynamicAssert(cycles <= 100000, "test timeout");
   endrule

   let strobe <- testStrobe();
   let sync <- testPinSync();

   function RStmt#(Bit#(0)) runTest(FSM test);
      return seq
                test.start();
                test.waitTillDone();
             endseq;
   endfunction
   mkAutoFSM(par
                runTest(strobe);
                runTest(sync);
             endpar);
endmodule

endpackage
