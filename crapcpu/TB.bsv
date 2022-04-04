package TB;

import Assert::*;
import StmtFSM::*;
import Cntrs::*;
import GetPut::*;
import ClientServer::*;
import FIFOF::*;

import ALU::*;
import Decode::*;
import ISA::*;
import Mem::*;
import CPU::*;

module mkTB ();
   Reg#(UInt#(32)) cycles <- mkReg(0);
   rule timeout;
      cycles <= cycles+1;
      dynamicAssert(cycles <= 100, "test timeout");
   endrule

   let decoder <- testDecoder();
   let alu <- testALU();
   let mem <- testMem();
   let cpu <- testCPU();

   function RStmt#(Bit#(0)) run(String name, FSM test);
      return seq
                $display("RUN ", name);
                test.start();
                test.waitTillDone();
                $display("OK  ", name);
             endseq;
   endfunction
   mkAutoFSM(seq
                //run("testDecoder", decoder);
                //run("testALU", alu);
                //run("testMem", mem);
                run("testCPU", cpu);
             endseq);
endmodule

module testDecoder (FSM);
   function RStmt#(Bit#(0)) checkEq(String name, Instruction in, Decoded want);
      return seq
                $display("  ", name);
                action
                   let got = decode(in);
                   // $display(fshow(got));
                   // $display(fshow(want));
                   dynamicAssert(got == want, strConcat("wrong instruction decode: ", name));
                endaction
             endseq;
   endfunction
   let fsm <- mkFSM(seq
      checkEq("add r0,r1,r2", 'b00_001_010_00_000_000, Decoded{
         ra: 1,
         rb: 2,
         rd: 0,
         imm: 0,
         func: Add,
         ra_not_zero: True,
         rb_not_imm: True,
         mem_en: False,
         mem_write: False,
         wb_en: True,
         jmp_mode: Never
         });
      checkEq("sub r4,r6,r7", 'b00_110_111_00_001_100, Decoded{
         ra: 6,
         rb: 7,
         rd: 4,
         imm: 0,
         func: Sub,
         ra_not_zero: True,
         rb_not_imm: True,
         mem_en: False,
         mem_write: False,
         wb_en: True,
         jmp_mode: Never
         });
      checkEq("and r4,r6,r7", 'b00_110_111_00_010_100, Decoded{
         ra: 6,
         rb: 7,
         rd: 4,
         imm: 0,
         func: And,
         ra_not_zero: True,
         rb_not_imm: True,
         mem_en: False,
         mem_write: False,
         wb_en: True,
         jmp_mode: Never
         });
      checkEq("or r4,r6,r7", 'b00_110_111_00_011_100, Decoded{
         ra: 6,
         rb: 7,
         rd: 4,
         imm: 0,
         func: Or,
         ra_not_zero: True,
         rb_not_imm: True,
         mem_en: False,
         mem_write: False,
         wb_en: True,
         jmp_mode: Never
         });
      checkEq("xor r4,r6,r7", 'b00_110_111_00_100_100, Decoded{
         ra: 6,
         rb: 7,
         rd: 4,
         imm: 0,
         func: Xor,
         ra_not_zero: True,
         rb_not_imm: True,
         mem_en: False,
         mem_write: False,
         wb_en: True,
         jmp_mode: Never
         });
      checkEq("shl r4,r6,r7", 'b00_110_111_00_101_100, Decoded{
         ra: 6,
         rb: 7,
         rd: 4,
         imm: 0,
         func: Shl,
         ra_not_zero: True,
         rb_not_imm: True,
         mem_en: False,
         mem_write: False,
         wb_en: True,
         jmp_mode: Never
         });
      checkEq("shr r4,r6,r7", 'b00_110_111_00_110_100, Decoded{
         ra: 6,
         rb: 7,
         rd: 4,
         imm: 0,
         func: Shr,
         ra_not_zero: True,
         rb_not_imm: True,
         mem_en: False,
         mem_write: False,
         wb_en: True,
         jmp_mode: Never
         });
      checkEq("add r4,r6,#42", 'b01_110_0101010_0_100, Decoded{
         ra: 6,
         rb: 0,
         rd: 4,
         imm: 42,
         func: Add,
         ra_not_zero: True,
         rb_not_imm: False,
         mem_en: False,
         mem_write: False,
         wb_en: True,
         jmp_mode: Never
         });
      checkEq("ld r4,[r6,#42]", 'b01_110_0101010_1_100, Decoded{
         ra: 6,
         rb: 0,
         rd: 4,
         imm: 42,
         func: Add,
         ra_not_zero: True,
         rb_not_imm: False,
         mem_en: True,
         mem_write: False,
         wb_en: True,
         jmp_mode: Never
         });
      checkEq("ld r4,#420", 'b10_00110100100_100, Decoded{
         ra: 0,
         rb: 0,
         rd: 4,
         imm: 420,
         func: Add,
         ra_not_zero: False,
         rb_not_imm: False,
         mem_en: False,
         mem_write: False,
         wb_en: True,
         jmp_mode: Never
         });
      checkEq("st r4,[r6,#42]", 'b11_110_100_00_101010, Decoded{
         ra: 6,
         rb: 4,
         rd: 0,
         imm: 42,
         func: Add,
         ra_not_zero: True,
         rb_not_imm: False,
         mem_en: True,
         mem_write: True,
         wb_en: False,
         jmp_mode: Never
         });
      checkEq("j r4,#42", 'b11_110_000_11_101010, Decoded{
         ra: 6,
         rb: 0,
         rd: 0,
         imm: 42,
         func: Add,
         ra_not_zero: True,
         rb_not_imm: False,
         mem_en: False,
         mem_write: False,
         wb_en: False,
         jmp_mode: Always
         });
      checkEq("jz r4,r6,#42", 'b11_110_100_01_101010, Decoded{
         ra: 6,
         rb: 4,
         rd: 0,
         imm: 42,
         func: Add,
         ra_not_zero: True,
         rb_not_imm: False,
         mem_en: False,
         mem_write: False,
         wb_en: False,
         jmp_mode: IfZero
         });
      endseq);
   return fsm;
endmodule

module testALU (FSM);
   function RStmt#(Bit#(0)) checkEq(String name, ALU_Input in, ALU_Output want);
      return seq
                $display("  ", name);
                action
                   let got = alu(in);
                   // $display("%x", got);
                   // $display("%x", want);
                   dynamicAssert(got == want, strConcat("wrong ALU result: ", name));
                endaction
             endseq;
   endfunction
   function ALU_Input alu_in(ALU_Op op, Word a, Word b, Word imm, Bool ra_not_zero, Bool rb_not_imm);
      return ALU_Input{
         op: op,
         a: a,
         b: b,
         imm: imm,
         ra_not_zero: ra_not_zero,
         rb_not_imm: rb_not_imm
      };
   endfunction
   function ALU_Output alu_out(Word o);
      return ALU_Output{
         o: o
      };
   endfunction

   let fsm <- mkFSM(seq
      checkEq("r + r", alu_in(Add, 1, 2, ?, True, True), alu_out(3));
      checkEq("r + i", alu_in(Add, 1, ?, 3, True, False), alu_out(4));
      checkEq("0 + r", alu_in(Add, ?, 2, ?, False, True), alu_out(2));
      checkEq("0 + i", alu_in(Add, ?, ?, 3, False, False), alu_out(3));
      checkEq("r - r", alu_in(Sub, 1, 2, ?, True, True), alu_out(65535));
      checkEq("r & r", alu_in(And, 1, 2, ?, True, True), alu_out(0));
      checkEq("r | r", alu_in(Or, 1, 2, ?, True, True), alu_out(3));
      checkEq("r ^ r", alu_in(Xor, 1, 3, ?, True, True), alu_out(2));
      checkEq("r << r", alu_in(Shl, 1, 2, ?, True, True), alu_out(4));
      checkEq("r >> r", alu_in(Shr, 4, 2, ?, True, True), alu_out(1));
    endseq);
   return fsm;
endmodule

module testMem (FSM);
   let imem <- mkIMem("test_mem.hex");
   let dmem <- mkDMem();
   Reg#(Bit#(8)) serial <- mkRegU(); // fake serial port
   let iomem <- mkIOOverlay(dmem, toGet(asReg(serial)), toPut(asReg(serial)));

   Count#(UInt#(32)) cycles <- mkCount(0);
   rule count_cycles;
      cycles.incr(1);
   endrule

   Reg#(UInt#(32)) c <- mkRegU();

   function Action assert_resp(Get#(Word) mem, Word want);
      return action
                let got <- mem.get();
                dynamicAssert(got == want, "wrong value from imem");
                dynamicAssert(cycles == (c+1), "imem didn't respond in 1 cycle");
             endaction;
   endfunction

   function Action assert_serial(Bit#(8) want);
      return action
                dynamicAssert(serial == want, "wrong value at serial port");
                dynamicAssert(cycles == (c+1), "iomem didn't respond in 1 cycle");
             endaction;
   endfunction

   function Action imem_send(Word addr);
      return action
                imem.request.put(addr);
                c <= cycles;
             endaction;
   endfunction

   function Action dmem_send(Word addr, Maybe#(Word) data);
      return action
                dmem.request.put(Mem_Request{
                   addr: addr,
                   data: data
                });
                c <= cycles;
             endaction;
   endfunction

   function Action iomem_send(Word addr, Maybe#(Word) data);
      return action
                iomem.request.put(Mem_Request{
                   addr: addr,
                   data: data
                });
                c <= cycles;
             endaction;
   endfunction

   let fsm <- mkFSM(seq
      imem_send('h0000);
      assert_resp(imem.response, 'h0123);
      imem_send('h0001);
      assert_resp(imem.response, 'h0123);
      imem_send('h0002);
      assert_resp(imem.response, 'h4567);

      dmem_send('h0000, tagged Valid 'h0123);
      dmem_send('h0002, tagged Valid 'h4567);
      dmem_send('h0000, tagged Invalid);
      assert_resp(dmem.response, 'h0123);
      dmem_send('h0001, tagged Invalid);
      assert_resp(dmem.response, 'h0123);
      dmem_send('h0002, tagged Invalid);
      assert_resp(dmem.response, 'h4567);

      iomem_send('hFFFF, tagged Valid 'h0123);
      assert_serial('h23);
      iomem_send('hFFFF, tagged Invalid);
      assert_resp(iomem.response, 'h0023);
      serial <= 'h42;
      iomem_send('hFFFF, tagged Invalid);
      assert_resp(iomem.response, 'h0042);
   endseq);
   return fsm;
endmodule

module testCPU (FSM);
   let imem <- mkIMem("cpu_test_mem.hex");
   let dmem <- mkDMem();
   Reg#(Bit#(8)) serial_in <- mkReg(32);
   Reg#(Bit#(8)) serial_out <- mkRegU();
   let iomem <- mkIOOverlay(dmem, toGet(asReg(serial_in)), toPut(asReg(serial_out)));
   let cpu <- mkCPU(iomem, imem);

   let fsm <- mkFSM(seq
      await (serial_out == 42);
   endseq);
   return fsm;
endmodule

endpackage
