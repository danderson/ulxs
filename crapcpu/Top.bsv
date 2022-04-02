package Top;

interface Top;
   (* always_ready *)
   method Bit#(8) leds();
   (* always_enabled *)
   method Action uart_rx(bit v);
   (* always_ready *)
   method bit uart_tx();
endinterface

module mkTop(Top);
   method Bit#(8) leds();
      return 0;
   endmethod
   method Action uart_rx(bit v);
   endmethod
   method bit uart_tx();
      return 1;
   endmethod
endmodule

endpackage
