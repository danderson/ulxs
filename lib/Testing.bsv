package Testing;

import Assert::*;
import StmtFSM::*;

interface TestCycleCounter;
   method UInt#(32) _read();
endinterface

module mkTestCycleCounter#(UInt#(32) max_cycles)(TestCycleCounter);
   Reg#(UInt#(32)) c <- mkReg(0);

   rule increment;
      dynamicAssert(c < max_cycles, "test timeout");
      c <= c+1;
   endrule

   method _read = c._read;
endmodule

module mkTest#(String name, RStmt#(Bit#(0)) test)();
   mkAutoFSM(seq
                $display("RUN ", name);
                test;
                $display("OK  ", name);
             endseq);
endmodule

endpackage
