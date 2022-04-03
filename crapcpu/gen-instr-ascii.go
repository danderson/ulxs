package main

import (
	"fmt"
	"math"
	"strconv"
	"strings"
)

var instructions = strings.TrimSpace(`
00 Ra(3) Rb(3) XX Op(3) Rd(3)
01 Ra(3) Imm(6) Op(2) Rd(3)
10 Imm(10) Op(1) Rd(3)
11 Ra(3) Rb(3) Op(2) Imm(6)
`)

func main() {
	var encodings [][]*Field
	for _, s := range strings.Split(instructions, "\n") {
		encodings = append(encodings, parseInstr(strings.Fields(s)))
	}

	var oneBitSize int
	for _, fs := range encodings {
		for _, f := range fs {
			obs := int(math.Ceil(float64(len(f.Raw)) / float64(f.Len)))
			if obs > oneBitSize {
				oneBitSize = obs
			}
		}
	}

	for _, fs := range encodings {
		for _, f := range fs {
			f.Raw = pad(f.Raw, oneBitSize*f.Len)
		}
	}

	for _, fs := range encodings {
		fmt.Print("+")
		for _, f := range fs {
			fmt.Print(header(f))
		}
		fmt.Print("\n")

		fmt.Print("|")
		for _, f := range fs {
			fmt.Print(f.Raw)
		}
		fmt.Print("\n")

		fmt.Print("+")
		for _, f := range fs {
			fmt.Print(header(f))
		}
		fmt.Print("\n\n")
	}
}

func parseInstr(s []string) []*Field {
	ret := []*Field{}
	for _, f := range s {
		if i := strings.Index(f, "("); i >= 0 {
			l, err := strconv.Atoi(f[i+1 : len(f)-1])
			if err != nil {
				panic("bad int")
			}
			ret = append(ret, &Field{
				Raw: " " + f + " |",
				Len: l,
			})
		} else {
			ret = append(ret, &Field{
				Raw: " " + f + " |",
				Len: len(f),
			})
		}
	}
	return ret
}

type Field struct {
	Raw string
	Len int
}

func header(f *Field) string {
	return strings.Repeat("-", len(f.Raw)-1) + "+"
}

func pad(s string, l int) string {
	if len(s) == l {
		return s
	} else if len(s) > l {
		panic("can't shorten with padding")
	}

	missing := l - len(s)
	lpad := missing / 2
	rpad := missing - lpad
	ret := strings.Repeat(" ", lpad) + s[:len(s)-1] + strings.Repeat(" ", rpad) + "|"
	return ret
}
