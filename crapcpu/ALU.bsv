package ALU;

import Decode::*;
import ISA::*;

typedef struct {
   ALU_Op op;
   Word a;
   Word b;
   Word imm;
   Bool ra_not_zero;
   Bool rb_not_imm;
} ALU_Input;

typedef struct {
   Word o;
} ALU_Output deriving (Eq);


function ALU_Output alu(ALU_Input f);
   function ALU_Output out(Word o);
      return ALU_Output{
         o: o
         };
   endfunction
   let a = f.ra_not_zero ? f.a : 0;
   let b = f.rb_not_imm ? f.b : f.imm;
   return case (f.op) matches
             Add: out(a + b);
             Sub: out(a - b);
             And: out(a & b);
             Or: out(a | b);
             Xor: out(a ^ b);
             Shl: out(a << b);
             Shr: out(a >> b);
          endcase;
endfunction

endpackage
