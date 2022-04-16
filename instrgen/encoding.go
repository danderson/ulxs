package main

import (
	"fmt"
	"math"
	"sort"
	"strconv"
	"strings"
)

type field struct {
	Name string
	Bits int
}

func (f field) String() string {
	if f.Bits == 0 {
		return f.Name + "(?)"
	}
	return fmt.Sprintf("%s(%d)", f.Name, f.Bits)
}

func (f field) Immediate() bool {
	return strings.HasPrefix(f.Name, "#")
}

type encoding struct {
	Name       shape
	Prefix     bits
	FillerBits int
	Fields     []*field
}

func (e encoding) String() string {
	var s strings.Builder
	s.WriteString(string(e.Name))
	s.WriteByte('{')
	first := true
	if pfx := e.Prefix.String(); pfx != "" {
		first = false
		s.WriteString("pfx(")
		s.WriteString(pfx)
		s.WriteString(")")
	}
	if e.FillerBits > 0 {
		if first {
			first = false
		} else {
			s.WriteString(", ")
		}
		s.WriteString("_(")
		s.WriteString(strconv.Itoa(e.FillerBits))
		s.WriteString(")")
	}
	for _, f := range e.Fields {
		if first {
			first = false
		} else {
			s.WriteString(", ")
		}
		s.WriteString(f.String())
	}
	s.WriteByte('}')
	return s.String()
}

func (e encoding) NumFields() int {
	ret := 1 + len(e.Fields)
	if e.FillerBits > 0 {
		ret++
	}
	return ret
}

func (e encoding) PrefixString() string {
	return fmt.Sprintf("%s=%s", e.Name, e.Prefix)
}

func (e encoding) Bits() int {
	var ret int
	for _, f := range e.Fields {
		ret += f.Bits
	}
	return ret + e.Prefix.Bits + e.FillerBits
}

func (e encoding) PossiblePrefixSize(instructionWidth int) int {
	ret := instructionWidth - e.Bits()
	if e.HasImmediate() {
		return ret + 1
	}
	return ret
}

func (e encoding) HasImmediate() bool {
	for _, f := range e.Fields {
		if f.Immediate() {
			return true
		}
	}
	return false
}

type bits struct {
	Value int
	Bits  int
}

func (b bits) String() string {
	var ret strings.Builder
	for i := 0; i < b.Bits; i++ {
		v := (b.Value >> (b.Bits - i - 1)) & 1
		if v == 1 {
			ret.WriteByte('1')
		} else {
			ret.WriteByte('0')
		}
	}
	return ret.String()
}

type encodedInstruction struct {
	Raw      *parsedInstruction
	Encoding *encoding
}

func computeEncodings(insns []*parsedInstruction, instructionWidth, registerWidth int) map[shape]*encoding {
	encodings := map[shape]*encoding{}
	counts := map[shape]int{}
	// Compile the instruction shapes in use.
	for _, insn := range insns {
		counts[insn.Shape()]++
		if _, ok := encodings[insn.Shape()]; ok {
			continue
		}
		e := &encoding{Name: insn.Shape()}
		for _, r := range insn.Registers {
			e.Fields = append(e.Fields, &field{
				Name: "r" + r,
				Bits: registerWidth,
			})
		}
		if insn.Immediate != "" {
			e.Fields = append(e.Fields, &field{
				Name: "#" + insn.Immediate,
				Bits: 0,
			})
		}
		encodings[insn.Shape()] = e
	}

	// Add in opcode fields, based on number of instructions using
	// each encoding.
	for shape, cnt := range counts {
		bits := log2ceil(cnt)
		if bits == 0 {
			continue
		}
		encodings[shape].Fields = append([]*field{
			&field{
				Name: "op",
				Bits: log2ceil(cnt),
			},
		}, encodings[shape].Fields...)
	}

	// Add opcode prefixes, using huffman codes.
	addPrefixes(encodings, instructionWidth)

	// Max out instructions where applicable.
perEnc:
	for _, encoding := range encodings {
		for _, f := range encoding.Fields {
			if !f.Immediate() {
				continue
			}
			f.Bits = instructionWidth - encoding.Bits()
			continue perEnc
		}
		encoding.FillerBits = instructionWidth - encoding.Bits()
	}

	return encodings
}

func addPrefixes(encodings map[shape]*encoding, instructionWidth int) {
	// Construct a Huffman tree of the encodings, using a heuristic of
	// how few bits we want the prefix to take
	leaves := make([]*huffTree, 0, len(encodings))
	sumProb := float64(0)
	maxPossibleImmBits := 0
	for _, e := range encodings {
		score := float64(1.0 / math.Pow(2, float64(e.PossiblePrefixSize(instructionWidth))))
		leaves = append(leaves, &huffTree{
			Value: e,
			Score: score,
		})
		sumProb += score
		if e.HasImmediate() {
			maxPossibleImmBits += instructionWidth - e.Bits()
		}
	}
	residual := float64(1-sumProb) * 0.9
	for _, e := range leaves {
		if e.Value.HasImmediate() {
			immBits := instructionWidth - e.Value.Bits()
			e.Score += residual * float64(immBits) / float64(maxPossibleImmBits)
		}
	}
	sort.Slice(leaves, func(i, j int) bool {
		return leaves[i].Score < leaves[j].Score
	})
	var trees []*huffTree

	pop := func(q []*huffTree) (*huffTree, []*huffTree) {
		return q[0], q[1:]
	}
	popSmallest := func() (ret *huffTree) {
		switch {
		case len(leaves) == 0:
			ret, trees = pop(trees)
		case len(trees) == 0:
			ret, leaves = pop(leaves)
		case leaves[0].Score < trees[0].Score:
			ret, leaves = pop(leaves)
		default:
			ret, trees = pop(trees)
		}
		return ret
	}
	for len(leaves) > 0 || len(trees) != 1 {
		a := popSmallest()
		b := popSmallest()
		trees = append(trees, &huffTree{
			Left:  a,
			Right: b,
			Score: a.Score + b.Score,
		})
	}

	// Walk the tree and add prefixes to all the encodings.
	var rec func(bits, *huffTree)
	rec = func(p bits, t *huffTree) {
		if t.Value != nil {
			t.Value.Prefix = p
			return
		}
		p.Bits++
		p.Value <<= 1
		rec(p, t.Left)
		p.Value++
		rec(p, t.Right)
	}
	rec(bits{}, trees[0])
}

type huffTree struct {
	Left, Right *huffTree
	Value       *encoding
	Score       float64
}

func log2ceil(v int) int {
	return int(math.Ceil(math.Log2(float64(v))))
}
