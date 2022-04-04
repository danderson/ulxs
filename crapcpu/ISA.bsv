package ISA;

typedef Bit#(16) PC;
typedef Bit#(16) GPR;
typedef Bit#(3) RegNum;

typedef Bit#(16) Word;
typedef Bit#(16) Instruction;

typedef enum {
   Add,
   Sub,
   And,
   Or,
   Xor,
   Shl,
   Shr
} ALU_Op deriving (Bits, Eq, FShow);

endpackage
