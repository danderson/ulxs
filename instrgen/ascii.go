package main

import (
	"math"
	"strings"
)

func AsciiArt(encodings map[shape]*encoding) map[shape]string {
	ret := map[shape]string{}

	oneBitSize := 0
	maxFields := 0
	biggerBits := func(raw string, bits int) {
		obs := int(math.Ceil(float64(len(raw)+2) / float64(bits)))
		if obs > oneBitSize {
			oneBitSize = obs
		}
	}
	for _, e := range encodings {
		biggerBits(e.PrefixString(), e.Prefix.Bits)
		for _, f := range e.Fields {
			biggerBits(f.String(), f.Bits)
		}
		if f := e.NumFields(); f > maxFields {
			maxFields = f
		}
	}

	for _, e := range encodings {
		var (
			extraFieldPad = maxFields - e.NumFields()
			prefixPad     = 0
			fillerPad     = 0
			immPad        = 0
		)
		if extraFieldPad > 0 {
			switch {
			case e.HasImmediate():
				immPad = extraFieldPad
			case e.FillerBits > 0:
				fillerPad = extraFieldPad
			default:
				prefixPad = extraFieldPad
			}
		}

		var h, v strings.Builder
		p := func(s string, bits int, extra int) {
			w := fieldWidth(bits, oneBitSize) + extra
			h.WriteString(header(w))
			v.WriteString(pad(s, w) + "|")
		}

		h.WriteByte('+')
		v.WriteByte('|')
		p(e.PrefixString(), e.Prefix.Bits, prefixPad)
		if e.FillerBits > 0 {
			p(strings.Repeat("x", e.FillerBits), e.FillerBits, fillerPad)
		}
		for _, f := range e.Fields {
			if f.Immediate() {
				p(f.String(), f.Bits, immPad)
			} else {
				p(f.String(), f.Bits, 0)
			}
		}
		h.WriteByte('\n')
		v.WriteByte('\n')
		ret[e.Name] = h.String() + v.String() + h.String()
	}

	return ret
}

func fieldWidth(bits int, oneBitSize int) int {
	return bits * oneBitSize
}

func header(len int) string {
	return strings.Repeat("-", len) + "+"
}

func pad(s string, total int) string {
	if len(s) == total {
		return s
	} else if len(s) > total {
		panic("can't shorten string")
	}

	missing := total - len(s)
	lpad := missing / 2
	rpad := missing - lpad
	ret := strings.Repeat(" ", lpad) + s + strings.Repeat(" ", rpad)
	return ret
}
