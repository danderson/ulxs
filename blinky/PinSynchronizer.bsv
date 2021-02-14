package PinSynchronizer;

module mkPinSync (Reg#(t)) provisos (Bits#(t, 1));
   Reg#(t) a <- mkReg(unpack(0));
   Reg#(t) b <- mkReg(unpack(0));

   method Action _write(t v);
	  a <= v;
	  b <= a;
   endmethod

   method _read = b._read;
endmodule

endpackage
