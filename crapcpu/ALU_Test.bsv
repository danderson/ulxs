package ALU_Test;

import Assert::*;
import StmtFSM::*;

import ALU::*;
import ISA::*;
import Testing::*;

module mkTB();
   let cycles <- mkTestCycleCounter(100);

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

   mkTest("ALU", seq
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
endmodule

endpackage
