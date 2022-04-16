package main

import (
	"bufio"
	"errors"
	"fmt"
	"os"
	"strconv"
	"strings"
)

type parsedInstruction struct {
	Name string
	// Registers is the list of abstract register names that the
	// instruction mentions. We remember the full abstract name so
	// that we can deduplicate struct fields in the decoder.
	Registers []string
	// Immediate is the name of the immediate field, or empty if the
	// instruction has no immediate operand.
	Immediate string
}

type pragmas struct {
	NumRegisters    int
	InstructionBits int
}

func (p *parsedInstruction) String() string {
	var args []string
	for _, r := range p.Registers {
		args = append(args, "r"+r)
	}
	if p.Immediate != "" {
		args = append(args, "#"+p.Immediate)
	}
	return fmt.Sprintf("%s %s", p.Name, strings.Join(args, ","))
}

type shape string

func (p *parsedInstruction) Shape() shape {
	var s strings.Builder
	for _, r := range p.Registers {
		s.WriteString(r)
	}
	if p.Immediate != "" {
		s.WriteByte('i')
	}
	if ret := s.String(); ret != "" {
		return shape(ret)
	}
	return "z"
}

func parse(path string) ([]*parsedInstruction, *pragmas, error) {
	f, err := os.Open(path)
	if err != nil {
		return nil, nil, err
	}
	defer f.Close()
	s := bufio.NewScanner(f)

	var (
		insns   []*parsedInstruction
		pragmas = &pragmas{}
	)
	for s.Scan() {
		t := strings.TrimSpace(s.Text())
		switch {
		case t == "":
			continue
		case strings.HasPrefix(t, "##"):
			if err := parsePragma(t, pragmas); err != nil {
				return nil, nil, fmt.Errorf("parsing %q: %w", t, err)
			}
		case strings.HasPrefix(t, "#"):
			continue
		default:
			is, err := parseInstruction(t)
			if err != nil {
				return nil, nil, fmt.Errorf("parsing %q: %w", t, err)
			}
			insns = append(insns, is...)
		}
	}
	if err := s.Err(); err != nil {
		return nil, nil, err
	}

	return insns, pragmas, nil
}

func parsePragma(l string, pragmas *pragmas) error {
	fs := strings.Fields(l[2:])
	if len(fs) != 2 {
		return fmt.Errorf("parsing %q: wrong number of fields for pragma")
	}
	switch fs[0] {
	case "num_registers":
		n, err := strconv.Atoi(fs[1])
		if err != nil {
			return err
		}
		pragmas.NumRegisters = n
		return nil
	case "instruction_bits":
		n, err := strconv.Atoi(fs[1])
		if err != nil {
			return err
		}
		pragmas.InstructionBits = n
		return nil
	default:
		return fmt.Errorf("unknown pragma %q", fs[0])
	}
}

func parseInstruction(l string) ([]*parsedInstruction, error) {
	fs := strings.Fields(l)
	switch len(fs) {
	case 1, 2:
	default:
		return nil, errors.New("unexpected field count")
	}

	names, err := expandMnemonic(fs[0])
	if err != nil {
		return nil, fmt.Errorf("expanding instruction mnemonic: %v", err)
	}

	var (
		regs []string
		imm  string
	)
	if len(fs) == 2 {
		seen := map[string]bool{}
		for _, f := range strings.Split(fs[1], ",") {
			if len(f) == 0 {
				return nil, errors.New("empty operand field")
			}
			switch f[0] {
			case '#':
				if imm != "" {
					return nil, errors.New("multiple immediates in instruction")
				}
				imm = f[1:]
			case 'r':
				if seen[f] {
					return nil, fmt.Errorf("register %q used multiple times in instruction", f)
				}
				seen[f] = true
				regs = append(regs, f[1:])
			default:
				return nil, fmt.Errorf("unknown operand kind %q", f)
			}
		}
	}

	var ret []*parsedInstruction
	for _, n := range names {
		insn := &parsedInstruction{
			Name:      n,
			Registers: append([]string(nil), regs...),
			Immediate: imm,
		}
		ret = append(ret, insn)
	}
	return ret, nil
}

func expandMnemonic(s string) ([]string, error) {
	if len(s) == 0 {
		panic("zero mnemonic")
	}
	if s[0] != '{' {
		return []string{s}, nil
	}
	if s[len(s)-1] != '}' {
		return nil, errors.New("unclosed mnemonic expansion")
	}
	return strings.Split(s[1:len(s)-1], ","), nil
}
