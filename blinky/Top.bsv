package Top;

import PinSynchronizer::*;

interface ITop;
   (* always_ready *)
   method Bit#(8) leds();
   (* always_enabled *)
   method Action btn1(bit v);
endinterface

module mkTop (ITop);
   Reg#(bit) run <- mkPinSync(0);
   Reg#(UInt#(28)) cnt <- mkReg(0);

   rule increment (run == 1);
	  cnt <= cnt + 1;
   endrule

   method Bit#(8) leds();
	  return pack(cnt)[27:20];
   endmethod

   method btn1 = run._write;
endmodule

endpackage
