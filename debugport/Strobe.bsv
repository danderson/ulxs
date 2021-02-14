package Strobe;

import Real::*;
import StmtFSM::*;
import Assert::*;

interface IStrobe;
   method Bool _read();
endinterface

module mkStrobeRaw #(parameter Integer reg_width,
					 parameter Integer reg_incr) (IStrobe);
   Reg#(UInt#(64)) cnt <- mkReg(0);

   let pw <- mkPulseWire();

   (* fire_when_enabled, no_implicit_conditions *)
   rule incr;
      let newCnt = cnt+fromInteger(reg_incr);
	  let p = pack(newCnt);
	  if (p[reg_width] == 1) pw.send();
	  cnt <= unpack(p[reg_width-1:0]);
   endrule

   method _read = pw._read;
endmodule

module mkStrobe #(parameter Integer main_clk_freq,
				  parameter Real strobe_freq) (IStrobe);
   // How far off the perfect clock ratio we're willing to be. If the
   // clocks don't divide perfectly into each other, the output will
   // jitter in small amounts around the ideal value.
   Real error_pct = 0.1;

   // How many main clock ticks per strobe. This will end up
   // fractional.
   Real target_ratio = fromInteger(main_clk_freq) / strobe_freq;

   Integer i = 0;
   Integer incr;
   // Try an i-bit wide counter, calculate how far off the perfect
   // ratio we are. Stop looping once we've found acceptable
   // parameters, or give up and return the largest counter we're
   // willing to have.
   for (Real actual_pct = 101; actual_pct > error_pct && i < 64; i=i+1) begin
	  Integer scaled_freq = 2**i;
	  // Given an i-bit counter, we have to increment by this much
	  // per cycle to hit the target strobe frequency.
	  incr = round(fromInteger(scaled_freq) * strobe_freq / fromInteger(main_clk_freq));
	  if (incr != 0) begin
		 Real actual_ratio = fromInteger(scaled_freq) / fromInteger(incr);
		 actual_pct = abs(actual_ratio - target_ratio) / target_ratio * 100;
	  end
   end

   let ret <- mkStrobeRaw(i-1, incr);
   return ret;
endmodule


module mkStrobeTest ();
   Reg#(UInt#(64)) cycles <- mkReg(0);
   rule count_cycles;
	  cycles <= cycles+1;
   endrule

   let raw <- mkStrobeRaw(8, 53);
   Reg#(UInt#(64)) raw_strobes <- mkReg(0);
   rule count_raw (raw);
	  raw_strobes <= raw_strobes+1;
   endrule
   rule check_raw (cycles == 256);
	  dynamicAssert(raw_strobes == 53, "wrong number of raw strobes");
   endrule

   let cooked <- mkStrobe(100, 23);
   Reg#(UInt#(64)) cooked_strobes <- mkReg(0);
   rule count_cooked (cooked);
	  cooked_strobes <= cooked_strobes+1;
   endrule
   rule check_cooked (cycles == 1001);
	  dynamicAssert(cooked_strobes == 230, "wrong number of cooked strobes");
   endrule

   mkAutoFSM(seq
			repeat (1002) noAction;
			$display("StrobeTest OK");
			$finish(0);
		 endseq);
endmodule

endpackage
