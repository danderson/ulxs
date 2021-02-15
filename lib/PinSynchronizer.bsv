package PinSynchronizer;

import StmtFSM::*;
import Assert::*;

module mkPinSync #(bit init_value) (Reg#(bit));
   Reg#(bit) a <- mkReg(init_value);
   Reg#(bit) b <- mkReg(init_value);

   rule advance;
      b <= a;
   endrule

   method _write = a._write;
   method _read = b._read;
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

endpackage
