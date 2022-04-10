package CPU;

import GetPut::*;
import ClientServer::*;

import ALU::*;
import Decode::*;
import ISA::*;
import Mem::*;
import RegFile::*;

typedef enum { Startup, Run, IO } State deriving (Bits, Eq, FShow);

module mkCPU #(Server#(Mem_Request, Word) dmem, Server#(Word, Word) imem) ();
   Reg#(Word) pc <- mkReg(0);
   Reg#(State) state <- mkReg(Startup);
   RegFile#(RegNum, Word) regs <- mkRegFileFull();

   rule init (state == Startup);
      imem.request.put(pc);
      state <= Run;
   endrule

   Reg#(RegNum) mem_wr_reg <- mkRegU();

   rule run_normal (state == Run);
      let insn <- imem.response.get();
      let dec = decode(insn);
      let a = regs.sub(dec.ra);
      let b = regs.sub(dec.rb);
      let alu_in = ALU_Input {
         op: dec.func,
         a: a,
         b: b,
         imm: dec.imm,
         ra_not_zero: dec.ra_not_zero,
         rb_not_imm: dec.rb_not_imm
      };
      let alu_out = alu(alu_in);

      if (dec.mem_en) begin
         dmem.request.put(Mem_Request{
            addr: alu_out.o,
            data: dec.mem_write ? tagged Valid b : tagged Invalid
         });
         if (dec.mem_write) begin
            let nextpc = pc+2;
            pc <= nextpc;
            imem.request.put(nextpc);
         end
         else begin
            mem_wr_reg <= dec.rd;
            state <= IO;
         end
      end
      else begin
         if (dec.wb_en) regs.upd(dec.rd, alu_out.o);
         let nextpc = pc;
         case (dec.jmp_mode) matches
            Never: nextpc = nextpc+2;
            Always: nextpc = alu_out.o;
            IfZero: if (alu_out.o == 0)
                       nextpc = b;
                    else
                       nextpc = nextpc+2;
         endcase
         pc <= nextpc;
         imem.request.put(nextpc);
      end
   endrule

   rule run_io (state == IO);
      let v <- dmem.response.get();
      regs.upd(mem_wr_reg, v);
      let nextpc = pc+2;
      imem.request.put(nextpc);
      pc <= nextpc;
      state <= Run;
   endrule
endmodule

endpackage
