package TB;

import Top::*;
import StmtFSM::*;

module mkTB ();
   let blinky <- mkTop ();

   rule pause;
	  blinky.btn1(True);
   endrule

   function Action assert_eq(Bit#(8) got, UInt#(8) want);
	  return action
				let gotv = unpack(got);
				if (gotv != want) action
				   $display("FAIL: got", gotv, " want", want);
				   $finish(1);
				endaction
			 endaction;
   endfunction

   let test = seq
				 noAction;
				 repeat (2<<19) assert_eq(blinky.leds, 0);
				 repeat (2<<19) assert_eq(blinky.leds, 1);
				 repeat (2<<19) assert_eq(blinky.leds, 2);
				 $display("OK");
				 $finish(0);
			  endseq;
   mkAutoFSM(test);
endmodule

endpackage
