package ALU

export ALU;

import ISA::*;

typedef enum {
   Add,
   Sub,
   And,
   Or,
   Xor,
   ShiftRight,
   ShiftLeft,
   Jump,
   JumpIfZero,
   JumpReg
} ALUOp deriving (Eq, Bits);

typedef struct {
   // Bits derived from the instruction being executed.
   ALUOp op;
   JumpOffset off;

   // Selected by the control logic.
   PC pc;
   GPR a, b;
} ALUInput;

typedef struct {
   GPR o;
   Bool jump;
} ALUOutput;

function ALUOutput ALU(ALUInput f);
  let ret = ALUOutput{
     o: 0,
     jump: False,
  };
  case f.op matches
     Add: ret.o = f.a + f.b;
     Sub: ret.o = f.a - f.b;
     And: ret.o = f.a & f.b;
     Or: ret.o = f.a | f.b;
     Xor: ret.o = f.a ^ f.b;
     ShiftRight: ret.o = f.a >> f.b;
     ShiftLeft: ret.o = f.a << f.b;
     Jump: begin
              ret.o = f.pc + (f.off << 1);
              ret.jump = True;
           end
     JumpIfZero: begin
                    ret.o = f.pc + (f.off << 1);
                    ret.jump = (f.a == 0);
                 end
     JumpReg: begin
                 ret.o = f.a & 'hFFFE;
                 ret.jump = True;
              end
  endcase
endfunction

endpackage
