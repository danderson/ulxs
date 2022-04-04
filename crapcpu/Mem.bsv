package Mem;

import ClientServer::*;
import GetPut::*;
import BRAM::*;

import ISA::*;

typedef struct {
   Word addr;
   Maybe#(Word) data;
} Mem_Request deriving (Bits, Eq);

module mkDMem (Server#(Mem_Request, Word));
   let cfg = BRAM_Configure{
      memorySize: 2048,
      latency: 1,
      outFIFODepth: 3,
      loadFormat: None,
      allowWriteResponseBypass: False
   };
   BRAM1Port#(Word, Word) ram <- mkBRAM1Server(cfg);

   interface Get response;
      method get = ram.portA.response.get;
   endinterface

   interface Put request;
      method Action put(Mem_Request req);
         BRAMRequest#(Word, Word) r = BRAMRequest {
            write: isValid(req.data),
            responseOnWrite: False,
            address: req.addr,
            datain: fromMaybe(0, req.data)
            };
         ram.portA.request.put(r);
      endmethod
   endinterface
endmodule

module mkIOOverlay #(Server#(Mem_Request, Word) dmem, Get#(Bit#(8)) sr, Put#(Bit#(8)) st) (Server#(Mem_Request, Word));
   Reg#(Bool) io_wait <- mkReg(False); // Next get() must return read from SerialReceiver

   interface Get response;
      method ActionValue#(Word) get();
         if (io_wait) begin
            let v <- sr.get();
            return zeroExtend(v);
         end
         else begin
            let v <- dmem.response.get();
            return v;
         end
      endmethod
   endinterface

   interface Put request;
      method Action put(Mem_Request req);
         if (req.addr == 'hFFFF) begin
            case (req.data) matches
               tagged Invalid: io_wait <= True;
               tagged Valid .v: st.put(truncate(v));
            endcase
         end
         else
            dmem.request.put(req);
      endmethod
   endinterface
endmodule

module mkIMem #(String hex) (Server#(Word, Word));
   let cfg = BRAM_Configure{
      memorySize: 2048,
      latency: 1,
      outFIFODepth: 3,
      loadFormat: tagged Hex hex,
      allowWriteResponseBypass: False
   };
   BRAM1Port#(Word, Word) ram <- mkBRAM1Server(cfg);

   interface Get response;
      method get = ram.portA.response.get;
   endinterface

   interface Put request;
      method Action put(Word addr);
         let r = BRAMRequest {
            write: False,
            responseOnWrite: False,
            address: addr,
            datain: ?
            };
         ram.portA.request.put(r);
      endmethod
   endinterface
endmodule

endpackage
