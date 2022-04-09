package PinSynchronizer_Test;

import Assert::*;
import StmtFSM::*;
import Testing::*;

import PinSynchronizer::*;
import Testing::*;

module mkTB();
   let cycles <- mkTestCycleCounter(2000);

   let s <- mkPinSync(0);
   mkTest("PinSynchronizer", seq
      s <= 1;
      dynamicAssert(s == 0, "synchronizer didn't synchronize");
      dynamicAssert(s == 1, "synchronizer too slow");
      s <= 0;
      dynamicAssert(s == 1, "synchronizer didn't synchronize");
      dynamicAssert(s == 0, "synchronizer too slow");
   endseq);
endmodule

endpackage
