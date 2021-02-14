package Top;

import Strobe::*;

interface ITop;
   (* always_ready *)
   method Bit#(8) leds();
   (* always_enabled *)
   method Action uart_rx(bit v);
endinterface

module mkTop (ITop);
   let s <- mkStrobe(25_000_000, 115200*16);

   Reg#(Bit#(8)) v <- mkReg(0);

   rule toggle (s);
      v <= ~v;
   endrule

   method leds = v;

   method Action uart_rx(bit val);
   endmethod
endmodule

endpackage
