package Top;

import PinSynchronizer::*;
import GetPut::*;

interface ITop;
   (* always_ready *)
   method Bit#(8) leds();
   (* always_enabled *)
   method Action btn1(Bool v);
endinterface

module mkTop (ITop);
   Reg#(Bool) run <- mkPinSync;
   Reg#(UInt#(32)) cnt <- mkReg(0);

   rule increment (run);
	  cnt <= cnt + 1;
   endrule

   method Bit#(8) leds();
	  return pack(cnt)[27:20];
   endmethod

   method btn1 = run._write;
endmodule

endpackage
