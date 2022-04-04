package Mem;

import ClientServer::*;
import GetPut::*;
import BRAM::*;
import FIFO::*;

import ISA::*;

typedef struct {
   Word addr;
   Maybe#(Word) data;
} Mem_Request deriving (Bits, Eq, FShow);

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
            address: req.addr>>1,
            datain: fromMaybe(0, req.data)
            };
         ram.portA.request.put(r);
      endmethod
   endinterface
endmodule

module mkIOOverlay #(Server#(Mem_Request, Word) dmem, Get#(Bit#(8)) sr, Put#(Bit#(8)) st) (Server#(Mem_Request, Word));
   FIFO#(Word) out <- mkFIFO();
   Get#(Word) getter = toGet(out);
   Reg#(Maybe#(Bool)) io_wait <- mkReg(tagged Invalid);

   rule dump;
      $display("IOMEM: ", fshow(io_wait));
   endrule

   rule io_read (isValid(io_wait) && fromMaybe(False, io_wait) == True);
      let v <- sr.get();
      out.enq(zeroExtend(v));
      io_wait <= tagged Invalid;
   endrule

   rule mem_read (isValid(io_wait) && fromMaybe(False, io_wait) == False);
      let v <- dmem.response.get();
      out.enq(v);
      io_wait <= tagged Invalid;
   endrule

   interface Get response;
      method get = getter.get;
      // method ActionValue#(Word) get();
      //    let is_io_read = fromMaybe(False, io_wait);
      //    if (is_io_read) begin
      //       let v <- sr.get();
      //       io_wait <= tagged Invalid;
      //       return zeroExtend(v);
      //    end
      //    else begin
      //       let v <- dmem.response.get();
      //       io_wait <= tagged Invalid;
      //       return v;
      //    end
      // endmethod
   endinterface

   interface Put request;
      method Action put(Mem_Request req) if (!isValid(io_wait));
         if (req.addr == 'hFFFF) begin
            case (req.data) matches
               tagged Invalid: begin
                  $display("I/O read start");
                  io_wait <= tagged Valid True;
               end
               tagged Valid .v: st.put(truncate(v));
            endcase
         end
         else begin
            dmem.request.put(req);
            io_wait <= isValid(req.data) ? tagged Valid False : tagged Invalid;
         end
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
            address: addr>>1,
            datain: ?
            };
         ram.portA.request.put(r);
      endmethod
   endinterface
endmodule

endpackage
