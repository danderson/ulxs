package PinSynchronizer;

module mkPinSync #(bit init_value) (Reg#(bit));
   Reg#(bit) a <- mkReg(init_value);
   Reg#(bit) b <- mkReg(init_value);

   rule advance;
      b <= a;
   endrule

   method _write = a._write;
   method _read = b._read;
endmodule

endpackage
