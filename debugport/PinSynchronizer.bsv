package PinSynchronizer;

module mkPinSync #(bit init_value) (Reg#(bit));
   Reg#(bit) a <- mkReg(init_value);
   Reg#(bit) b <- mkReg(init_value);

   method Action _write(bit v);
	  a <= v;
	  b <= a;
   endmethod

   method _read = b._read;
endmodule

endpackage
