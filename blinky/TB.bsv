package TB;

import Blinky::*;
import StmtFSM::*;

module mkTB ();
   let blinky <- mkBlinky ();

   rule pause;
	  blinky.pause(False);
   endrule

   let test = seq
				 $display("running sequence test! LEDs ", blinky.leds);
				 $display("next ", blinky.leds);
				 $finish(0);
			  endseq;
   mkAutoFSM(test);
endmodule

endpackage
