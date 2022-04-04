package main

import (
	"bufio"
	"bytes"
	"errors"
	"fmt"
	"io"
	"os"
	"strconv"
	"strings"
)

func main() {
	instrs, err := parse(os.Args[1])
	if err != nil {
		fatal("parsing %q: %v", os.Args[1], err)
	}

	for _, instr := range instrs {
		fmt.Print(instr.Name, " ")
		for _, reg := range instr.Regs {
			fmt.Print(reg, " ")
		}
		if instr.HasImm {
			fmt.Print("#", instr.Imm)
		}
		fmt.Print("\n")
	}

	if err := assemble(os.Args[2], instrs); err != nil {
		fatal("assembling %q: %v", os.Args[1], err)
	}
}

func assemble(path string, insns []Instr) error {
	f, err := os.Create(path)
	if err != nil {
		return err
	}
	defer f.Close()

	for _, insn := range insns {
		fun := asms[insn.Name]
		if fun == nil {
			return fmt.Errorf("unknown mnemonic %q in %q", insn.Name, insn)
		}
		if err := fun(f, insn); err != nil {
			return err
		}
	}
	if err := f.Close(); err != nil {
		return fmt.Errorf("closing %q: %w", path, err)
	}

	return nil
}

type Instr struct {
	Name   string
	Regs   []int
	HasImm bool
	Imm    int
}

func (i Instr) String() string {
	var b bytes.Buffer
	fmt.Fprintf(&b, "%s ", i.Name)
	for _, reg := range i.Regs {
		fmt.Fprintf(&b, "r%d,", reg)
	}
	if i.HasImm {
		fmt.Fprintf(&b, "#%d,", i.Imm)
	}
	ret := b.String()
	return ret[:len(ret)-1]
}

type AsmFunc func(io.Writer, Instr) error

var asms = map[string]AsmFunc{
	"add":  asm1,
	"sub":  asm1,
	"and":  asm1,
	"or":   asm1,
	"xor":  asm1,
	"shl":  asm1,
	"shr":  asm1,
	"addi": asm2,
	"ld":   asm2,
	"ldi":  asm3,
	"st":   asm4,
	"jz":   asm4,
	"j":    asm4,
	"mov":  asmMov,
	"nop":  asmNop,
}

var alu = map[string]uint16{
	"add": 0,
	"sub": 1,
	"and": 2,
	"or":  3,
	"xor": 4,
	"shl": 5,
	"shr": 6,
}

func asm1(w io.Writer, i Instr) error {
	if err := checkOperands(i, 3, false); err != nil {
		return err
	}
	v := uint16(0<<14) | reg(i.Regs[1], 11) | reg(i.Regs[2], 8) | (alu[i.Name] << 3) | reg(i.Regs[0], 0)
	return write16(w, v)
}

func asm2(w io.Writer, i Instr) error {
	if err := checkOperands(i, 2, true); err != nil {
		return err
	}
	var op uint16
	switch i.Name {
	case "addi":
		op = 0
	case "ld":
		op = 1
	default:
		fmt.Println(i)
		panic("can't assemble insn")
	}
	v := uint16(1<<14) | reg(i.Regs[1], 11) | imm(i.Imm, 7, 4) | (op << 3) | reg(i.Regs[0], 0)
	return write16(w, v)
}

func asm3(w io.Writer, i Instr) error {
	if err := checkOperands(i, 1, true); err != nil {
		return err
	}
	v := uint16(2<<14) | imm(i.Imm, 11, 3) | reg(i.Regs[0], 0)
	return write16(w, v)
}

func asm4(w io.Writer, i Instr) error {
	var err error
	if i.Name == "j" {
		err = checkOperands(i, 1, true)
	} else {
		err = checkOperands(i, 2, true)
	}
	if err != nil {
		return err
	}
	var op uint16
	switch i.Name {
	case "st":
		op = 0
	case "jz":
		op = 1
	case "j":
		op = 2
	default:
		panic("unknown insn")
	}
	v := uint16(3<<14) | reg(i.Regs[0], 11) | (op << 6) | imm(i.Imm, 6, 0)
	if i.Name != "j" {
		v |= reg(i.Regs[1], 8)
	}
	return write16(w, v)
}

func asmMov(w io.Writer, i Instr) error {
	if err := checkOperands(i, 2, false); err != nil {
		return err
	}
	i2 := Instr{
		Name: "or",
		Regs: []int{i.Regs[0], i.Regs[1], i.Regs[1]},
	}
	return asm1(w, i2)
}

func asmNop(w io.Writer, i Instr) error {
	if err := checkOperands(i, 0, false); err != nil {
		return err
	}
	i2 := Instr{
		Name: "or",
		Regs: []int{0, 0, 0},
	}
	return asm1(w, i2)
}

func write16(w io.Writer, v uint16) error {
	_, err := fmt.Fprintf(w, "%04x\n", v)
	return err
}

func reg(r, sh int) uint16 {
	return uint16(r&7) << sh
}

func imm(i, bits, sh int) uint16 {
	mask := ^(0xFFFF << bits)
	return uint16(i&mask) << sh
}

func checkOperands(i Instr, regs int, imm bool) error {
	if l := len(i.Regs); l != regs {
		return fmt.Errorf("instruction %q has %d register operands, want %d", i, l, regs)
	}
	if i.HasImm && !imm {
		return fmt.Errorf("instruction %q can't have an immediate operand", i)
	} else if !i.HasImm && imm {
		return fmt.Errorf("instruction %q missing immediate operand", i)
	}
	return nil
}

func fatal(msg string, args ...any) {
	fmt.Fprintf(os.Stderr, msg+"\n", args...)
	os.Exit(1)
}

func parse(path string) ([]Instr, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, fmt.Errorf("opening %q: %w", path, err)
	}
	defer f.Close()

	var ret []Instr
	s := bufio.NewScanner(f)
	for s.Scan() {
		t := strings.TrimSpace(s.Text())
		if t == "" {
			continue
		}
		i, err := parseLine(t)
		if err != nil {
			return nil, fmt.Errorf("parsing %q: %w", t, err)
		}
		ret = append(ret, i)
	}
	if s.Err(); err != nil {
		return nil, err
	}

	return ret, nil
}

func parseLine(l string) (Instr, error) {
	for _, cut := range []string{"[", "]", ","} {
		l = strings.ReplaceAll(l, cut, " ")
	}
	fs := strings.Fields(l)
	ret := Instr{
		Name: fs[0],
	}
	for _, arg := range fs[1:] {
		if strings.HasPrefix(arg, "#") {
			if ret.HasImm {
				return Instr{}, errors.New("multiple immediates not allowed")
			}
			i, err := strconv.Atoi(arg[1:])
			if err != nil {
				return Instr{}, fmt.Errorf("immediate %q is not a number: %w", arg, err)
			}
			ret.HasImm = true
			ret.Imm = i
		} else {
			r, err := register(arg)
			if err != nil {
				return Instr{}, err
			}
			ret.Regs = append(ret.Regs, r)
		}
	}

	return ret, nil
}

func register(s string) (int, error) {
	if !strings.HasPrefix(s, "r") {
		return 0, fmt.Errorf("invalid register specifier %q", s)
	}
	i, err := strconv.Atoi(s[1:])
	if err != nil {
		return 0, fmt.Errorf("register %q is not a number: %w", s, err)
	}
	if i < 0 || i > 7 {
		return 0, fmt.Errorf("invalid register number %q, valid range is 0-7", s)
	}
	return i, nil
}
