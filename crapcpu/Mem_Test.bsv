package Mem_Test;

import Assert::*;
import ClientServer::*;
import FIFO::*;
import GetPut::*;
import StmtFSM::*;

import ISA::*;
import Mem::*;
import Testing::*;

module mkTB();
   let cycles <- mkTestCycleCounter(100);

   let imem <- mkIMem("test_mem.hex");
   let dmem <- mkDMem();
   FIFO#(Bit#(8)) into_mem <- mkFIFO();
   FIFO#(Bit#(8)) from_mem <- mkFIFO();
   let iomem <- mkIOOverlay(dmem, toGet(into_mem), toPut(from_mem));

   Reg#(UInt#(32)) imem_cycles_start <- mkRegU();
   function Action imem_send(Word addr);
      return action
                imem.request.put(addr);
                imem_cycles_start <= cycles;
             endaction;
   endfunction
   function Action assert_imem_resp(Word want);
      return action
                let got <- imem.response.get();
                dynamicAssert(got == want, "wrong value from imem");
                dynamicAssert(cycles == imem_cycles_start+1, "imem didn't respond in 1 cycle");
             endaction;
   endfunction

   Reg#(UInt#(32)) dmem_cycles_start <- mkRegU();
   function Action dmem_send(Word addr, Maybe#(Word) data);
      return action
                dmem.request.put(Mem_Request{
                   addr: addr,
                   data: data
                });
                dmem_cycles_start <= cycles;
             endaction;
   endfunction
   function Action assert_dmem_resp(Word want);
      return action
                let got <- dmem.response.get();
                dynamicAssert(got == want, "wrong value from dmem");
                dynamicAssert(cycles == dmem_cycles_start+1, "dmem didn't respond in 1 cycle");
             endaction;
   endfunction

   Reg#(UInt#(32)) iomem_cycles_start <- mkRegU();
   function Action iomem_send(Word addr, Maybe#(Word) data);
      return action
                iomem.request.put(Mem_Request{
                   addr: addr,
                   data: data
                });
                iomem_cycles_start <= cycles;
             endaction;
   endfunction
   function Action assert_iomem_resp(Word want);
      return action
                let got <- iomem.response.get();
                dynamicAssert(got == want, "wrong value from iomem");
                dynamicAssert(cycles == iomem_cycles_start+1, "iomem didn't respond in 1 cycle");
             endaction;
   endfunction
   function Action assert_serial(Bit#(8) want);
      return action
                dynamicAssert(from_mem.first == want, "wrong value at serial port");
                dynamicAssert(cycles == (iomem_cycles_start+1), "iomem didn't respond in 1 cycle");
                from_mem.deq();
             endaction;
   endfunction

   mkTest("Mem", seq
      $display("  imem");
      imem_send('h0000);
      assert_imem_resp('h0123);
      imem_send('h0001);
      assert_imem_resp('h0123);
      imem_send('h0002);
      assert_imem_resp('h4567);

      $display("  dmem");
      dmem_send('h0000, tagged Valid 'h0123);
      dmem_send('h0002, tagged Valid 'h4567);
      dmem_send('h0000, tagged Invalid);
      assert_dmem_resp('h0123);
      dmem_send('h0001, tagged Invalid);
      assert_dmem_resp('h0123);
      dmem_send('h0002, tagged Invalid);
      assert_dmem_resp('h4567);

      $display("  iomem");
      iomem_send('hFFFF, tagged Valid 'h0123);
      assert_serial('h23);
      into_mem.enq('h45);
      iomem_send('hFFFF, tagged Invalid);
      assert_iomem_resp('h0045);
      into_mem.enq('h46);
      iomem_send('hFFFF, tagged Invalid);
      assert_iomem_resp('h0046);
   endseq);
endmodule

endpackage
