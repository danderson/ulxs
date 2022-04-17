package main

import (
	"bufio"
	"bytes"
	"fmt"
	"os"
	"strconv"
	"strings"
)

type asmInstruction struct {
	Name         string
	Registers    []int
	HasImmediate bool
	Immediate    int
}

func (a *asmInstruction) String() string {
	var operands []string
	for _, r := range a.Registers {
		operands = append(operands, fmt.Sprintf("r%d", r))
	}
	if a.HasImmediate {
		operands = append(operands, fmt.Sprintf("#%d", a.Immediate))
	}
	return fmt.Sprintf("%s %s", a.Name, strings.Join(operands, ","))
}

func assemble(insns []*asmInstruction, encodings []*encodedInstruction) ([]byte, error) {
	var ret bytes.Buffer
nextInsn:
	for _, insn := range insns {
		for _, enc := range encodings {
			if !shapeMatches(insn, enc) {
				continue
			}

			e := enc.Encoding
			regs := insn.Registers
			var raw uint16
			raw |= uint16(e.Prefix.Value)
			raw <<= e.FillerBits
			for _, f := range e.Fields {
				switch {
				case f.Name == "op":
					raw <<= f.Bits
					raw |= uint16(enc.Opcode)
				case strings.HasPrefix(f.Name, "#"):
					raw <<= f.Bits
					raw |= uint16(insn.Immediate)
				case strings.HasPrefix(f.Name, "r"):
					raw <<= f.Bits
					raw |= uint16(regs[0])
					regs = regs[1:]
				default:
					return nil, fmt.Errorf("unknown field kind %q", f.Name)
				}
			}
			fmt.Fprintf(&ret, "%016b %s\n", raw, insn)

			continue nextInsn
		}
		return nil, fmt.Errorf("unknown instruction %q", insn)
	}
	return ret.Bytes(), nil
}

func shapeMatches(insn *asmInstruction, encoding *encodedInstruction) bool {
	if insn.Name != encoding.Raw.Name {
		return false
	}
	if len(insn.Registers) != len(encoding.Raw.Registers) {
		return false
	}
	if insn.HasImmediate != (encoding.Raw.Immediate != "") {
		return false
	}
	return true
}

func parseAsm(path string) ([]*asmInstruction, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, fmt.Errorf("opening %q: %w", path, err)
	}
	defer f.Close()

	var (
		instr      []*asmInstruction
		labels     = map[string]int{}
		needLabels = map[int]string{} // which offsets in instr need a label resolved
	)
	s := bufio.NewScanner(f)
	byteoff := 0
	for s.Scan() {
		t := strings.TrimSpace(s.Text())
		if t == "" {
			continue
		}
		if strings.HasPrefix(t, "#") {
			continue
		}
		if strings.HasSuffix(t, ":") {
			l := strings.TrimSuffix(t, ":")
			if _, ok := labels[l]; ok {
				return nil, fmt.Errorf("multiple definitions of label %q", l)
			}
			labels[l] = byteoff
			continue
		}
		t = strings.ReplaceAll(t, ",", " ")
		fs := strings.Fields(t)
		ins := &asmInstruction{
			Name: fs[0],
		}
		for _, arg := range fs[1:] {
			switch {
			case strings.HasPrefix(arg, "#"):
				if ins.HasImmediate {
					return nil, fmt.Errorf("instruction %q has multiple immediates", t)
				}
				i, err := strconv.Atoi(arg[1:])
				if err != nil {
					return nil, fmt.Errorf("immediate %q is not a number: %w", arg, err)
				}
				ins.HasImmediate = true
				ins.Immediate = i
			case strings.HasPrefix(arg, "r"):
				i, err := strconv.Atoi(arg[1:])
				if err != nil {
					return nil, fmt.Errorf("register %q is not a number: %w", arg, err)
				}
				ins.Registers = append(ins.Registers, i)
			default:
				if _, ok := needLabels[byteoff]; ok {
					return nil, fmt.Errorf("instruction %q has multiple labels", t)
				}
				needLabels[byteoff/2] = arg
			}
		}
		instr = append(instr, ins)
		byteoff += 2
	}
	if err := s.Err(); err != nil {
		return nil, fmt.Errorf("parse error: %w", err)
	}

	for off, label := range needLabels {
		l, ok := labels[label]
		if !ok {
			return nil, fmt.Errorf("reference to unknown label %q", label)
		}
		instr[off].HasImmediate = true
		instr[off].Immediate = l
	}

	return instr, nil
}
