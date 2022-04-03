This is a single stage CPU, implementing a rubbish minimal instruction
set as a way to become more familiar with BSV and knock the rust off
my old CPU design classes. The highlights:

 - Harvard architecture, strictly separate instruction and data
   memories. That way I can do instruction and data IO simultaneously
   without having to figure out a memory hierarchy just yet.
 - load-store architecture, all instructions other than ld/st are
   purely register-register.
 - 16-bit registers and instructions.
 - 8 registers. Not sure if PC will be one of them yet.
 - Instruction and data access must be 16-bit aligned.
 - All instructions execute in 1 cycle, assuming memory access is
   single-cycle (which it is, in this toy).
 - Single stage datapath, because I don't want to have to re-learn
   pipelining and hazards just yet. Throughput and max. frequency are
   both going to be crap.
 - No exceptions or interrupts.

```
                                                                              jz
                                                                ┌──────────┐   │
                                                                │  pc_src  │ ┌─▼┐   ┌───┐
┌─────────────┐                                               ┌─▼┐         │ │  │◄──┤ 1 │
│             │                    ┌────┐                     │  │◄──────┐ │ │  │   └───┘
│             │◄───────────────────┤ PC │◄────────────────────┼──┤       │ └─┤  │
│ Instruction │                    └────┘                     │  │◄─┐    │   │  │   ┌──┐
│    Fetch    │                                               └──┘  │    │   │  │◄──┤=0│◄─┐
│             │                     ┌──┐                            │    │   └──┘   └──┘  │
│             ├────────────────────►│+2├────────────────────────────┘    │                │
└──────┬──────┘                     └──┘                                 │                │
       │                                          ┌──────────────────────┼──o─────────────┘
       │                                          │    use_rb            │  │
┌──────▼──────┐              Ra ┌────────────┐    │      │       func    │  │ data_in ┌──────────┐
│             ├─────────────────┤            │    │     ┌▼─┐      │      │  └────────►│          │
│             ├─►use_ra         │            ├────o────►│  │   ┌──▼────┐ │            │          │
│             │              Rb │            │B         │  ├──►│       │ │   mem_en──►│  Memory  │
│             ├────────────────►│            │          │  │   │       │ │            │   Unit   │
│             ├─►use_rb         │            │    Imm──►│  │   └─┐     │ │   mem_wr──►│          │
│ Instruction │              Rd │  Register  │          └──┘     │     │ │            │          │
│   Decoder   ├────────────────►│    File    │                   │ ALU ├─o───o───────►│          ├─┐
│             ├─►Imm            │            │  ┌───┐   ┌──┐     │     │     │   addr └──────────┘ │
│             │           Rd_wr │            │  │ 0 ├──►│  │   ┌─┘     │     │                     │
│             ├────────────────►│            │  └───┘   │  │   │       │     │                     │
│             ├─►func           │            │A         │  ├──►│       │     │                     │
│             │           Rd_in │            ├─────────►│  │   └───────┘     │                     │
│             ├─►mem_en     ┌──►│            │          └▲─┘                 │                     │
│             ├─►mem_wr     │   └────────────┘           │          ┌──┐     │                     │
│             │             │                          use_ra       │  │◄────┘alu_out              │
│             ├─►use_mem    └───────────────────────────────────────┤  │                           │
│             ├─►jz                                                 │  │      mem_in               │
└─────────────┘                                                     │  │◄──────────────────────────┘
                                                                    └▲─┘
                                                                     │
                                                                  use_mem
```

## Instructions

| Family  | Mnemonic          | Effect                             | Encoding |
| ------- | ----------------- | ---------------------------------- | -------- |
| Arith   | `add rd,ra,rb`    | `rd = ra + rb`                     | 1        |
| Arith   | `sub rd,ra,rb`    | `rd = ra - rb`                     | 1        |
| Arith   | `and rd,ra,rb`    | `rd = ra & rb`                     | 1        |
| Arith   | `or rd,ra,rb`     | `rd = ra \| rb`                    | 1        |
| Arith   | `xor rd,ra,rb`    | `rd = ra ^ rb`                     | 1        |
| Arith   | `shl rd,ra,rb`    | `rd = ra << rb`                    | 1        |
| Arith   | `shr rd,ra,rb`    | `rd = ra >> rb`                    | 1        |
| Arith   | `add rd,ra,#imm`  | `rd = ra + imm`                    | 2        |
| Memory  | `ld rd,[ra,#imm]` | `rd = mem[trunc16(ra + imm)]`      | 2        |
| Memory  | `ld rd,#imm`      | `rd = imm`                         | 3        |
| Memory  | `st rb,[ra,#imm]` | `mem[trunc16(ra + imm)] = rb`      | 4        |
| Control | `jz rb,ra,#imm`   | `pc = rb ? pc : trunc16(ra + imm)` | 4        |
| Control | `j ra,#imm`       | `pc = trunc16(ra + imm)`           | 4        |
| Misc    | `mov rd,ra`       | same as `or rd,ra,ra`              | n/a      |
| Misc    | `nop`             | same as `or r0,r0,r0`              | n/a      |

### Encodings

Encoding 1 is for `register<op>register -> register` ALU ops

```
+---------------+-----------------------+-----------------------+---------------+-----------------------+-----------------------+
|      00       |         Ra(3)         |         Rb(3)         |      XX       |         Op(3)         |         Rd(3)         |
+---------------+-----------------------+-----------------------+---------------+-----------------------+-----------------------+
```

Encoding 2 is for `op(register+immediate) -> register` ALU ops and memory reads

```
+---------------+-----------------------+-------------------------------------------------------+-------+-----------------------+
|      01       |         Ra(3)         |                        Imm(7)                         | Op(1) |         Rd(3)         |
+---------------+-----------------------+-------------------------------------------------------+-------+-----------------------+
```

Encoding 3 is for `immediate -> register` initializations.

```
+---------------+---------------------------------------------------------------------------------------+-----------------------+
|      10       |                                        Imm(11)                                        |         Rd(3)         |
+---------------+---------------------------------------------------------------------------------------+-----------------------+
```

Encoding 4 is for memory stores and control flow operations.

```
+---------------+-----------------------+-----------------------+---------------+-----------------------------------------------+
|      11       |         Ra(3)         |         Rb(3)         |     Op(2)     |                    Imm(6)                     |
+---------------+-----------------------+-----------------------+---------------+-----------------------------------------------+
```
