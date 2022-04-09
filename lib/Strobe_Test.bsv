package Strobe_Test;

import Assert::*;
import StmtFSM::*;

import Testing::*;
import Strobe::*;

module mkTB();
   let cycles <- mkTestCycleCounter(2000);

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

   mkTest("Strobe", seq
      await(cycles == 255);
      dynamicAssert(raw_strobes == 53, "wrong number of raw strobes");
      await(cycles == 1000);
      dynamicAssert(cooked_strobes == 230, "wrong number of cooked strobes");
   endseq);
endmodule

endpackage
