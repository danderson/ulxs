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
| Arith   | `inc rd,#imm`     | `rd = rd + imm`                    | 3        |
| Memory  | `ld rd,[ra,#imm]` | `rd = mem[trunc16(ra + imm)]`      | 2        |
| Memory  | `ld rd,#imm`      | `rd = imm`                         | 3        |
| Memory  | `st rb,[ra,#imm]` | `mem[trunc16(ra + imm)] = rb`      | 2        |
| Control | `jz rb,ra,#imm`   | `pc = rb ? pc : trunc16(ra + imm)` | 2        |
| Control | `j ra,#imm`       | `pc = trunc16(ra + imm)`           | 3        |
| Misc    | `mov rd,ra`       | same as `or rd,ra,ra`              | n/a      |
| Misc    | `nop`             | same as `or r0,r0,r0`              | n/a      |

### 3-register encoding

```
+----+--------+------------------+--------+--------+
| 00 | Rd (3) |     ALU (5)      | Rb (3) | Ra (3) |
+----+--------+------------------+--------+--------+
```

 - `Ra`, `Rb`, `Rd`: register number, 0-7
 - `Op`: operation
   - `00`: ALU operation
 - `ALU`: ALU operation
   - `00000`: add
   - `00001`: sub
   - `00010`: and
   - `00011`: or
   - `00100`: XOR
   - `00101`: shift left
   - `00110`: shift right

### 2-register immediate encoding

```
+----+--------+--------+------------------+--------+
| 10 | Rd (3) | Op (2) |     Imm (6)      | Ra (3) |
+----+--------+--------+------------------+--------+
```

 - `Ra`, `Rd`: register number, 0-7
 - `Op`: operation
   - `00`: load register+immediate
   - `01`: store register+immediate
   - `10`: jump if zero
   - `11`: add register+immediate
 - `Imm`: 6-bit immediate value

### 1-register immediate encoding

```
+----+--------+--------+---------------------------+
| 11 | Rd (3) | Op (2) |         Imm (10)          |
+----+--------+--------+---------------------------+
```

 - `Rd`: register number, 0-7
 - `Op`: operation
   - `00`: jump register+immediate
   - `01`: load immediate
   - `10`: increment immediate
   - `11`: reserved

### Reserved

```
+----+---------------------------------------------+
| 01 |                  Reserved                   |
+----+---------------------------------------------+
```
