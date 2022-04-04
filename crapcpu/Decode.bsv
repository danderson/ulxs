package Decode;

import ISA::*;

typedef enum {
   Never,
   Always,
   IfZero
} Jump_Mode deriving (Bits, Eq, FShow);

typedef struct{
   // Extracted instruction bits
   RegNum ra;
   RegNum rb;
   RegNum rd;
   Word imm;
   // Control signals
   ALU_Op func;
   Bool ra_not_zero;
   Bool rb_not_imm;
   Bool mem_en;
   Bool mem_write;
   Bool wb_en;
   Jump_Mode jmp_mode;
} Decoded deriving (Bits, Eq, FShow);

function Decoded decode(Instruction instr);
   let ra = instr[13:11];
   let rb = instr[10:8];
   let rd = instr[2:0];
   case (instr[15:14]) matches
      'b00: return Decoded {
         ra: ra,
         rb: rb,
         rd: rd,
         imm: 0,
         func: unpack(instr[5:3]),
         ra_not_zero: True,
         rb_not_imm: True,
         mem_en: False,
         mem_write: False,
         wb_en: True,
         jmp_mode: Never
         };
      'b01: return Decoded {
         ra: ra,
         rb: 0,
         rd: rd,
         imm: zeroExtend(instr[10:4]),
         func: Add,
         ra_not_zero: True,
         rb_not_imm: False,
         mem_en: instr[3] == 1,
         mem_write: False,
         wb_en: True,
         jmp_mode: Never
         };
      'b10: return Decoded {
         ra: 0,
         rb: 0,
         rd: rd,
         imm: zeroExtend(instr[13:3]),
         func: Add,
         ra_not_zero: False,
         rb_not_imm: False,
         mem_en: False,
         mem_write: False,
         wb_en: True,
         jmp_mode: Never
         };
      'b11: return Decoded{
         ra: ra,
         rb: rb,
         rd: 0,
         imm: zeroExtend(instr[5:0]),
         func: Add,
         ra_not_zero: True,
         rb_not_imm: False,
         mem_en: instr[6] == 0,
         mem_write: instr[6] == 0,
         wb_en: False,
         jmp_mode: instr[6] == 0 ? Never : (instr[7] == 1 ? Always : IfZero)
         };
   endcase
endfunction

endpackage
