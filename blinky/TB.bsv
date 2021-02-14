package TB;

import Top::*;
import StmtFSM::*;

module mkTB ();
   let blinky <- mkTop ();

   rule pause;
	  blinky.btn1(True);
   endrule

   let test = seq
				 $display("running sequence test! LEDs ", blinky.leds);
				 $display("next ", blinky.leds);
				 $finish(0);
			  endseq;
   mkAutoFSM(test);
endmodule

endpackage
