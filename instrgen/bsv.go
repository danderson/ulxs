package main

import (
	"bytes"
	"fmt"
	"sort"
	"strings"
)

func genDecoder(insns []*encodedInstruction, encodings map[shape]*encoding, instructionWidth int) []byte {
	var ret bytes.Buffer

	names := globalOpcodeNames(insns)
	largestPrefix := 0
	for _, e := range encodings {
		if e.Prefix.Bits > largestPrefix {
			largestPrefix = e.Prefix.Bits
		}
	}

	ret.WriteString("package RawDecoder;\n\n")

	ret.WriteString("typedef enum {\n")
	for i, codes := range names {
		if i > 0 {
			ret.WriteString(",\n")
		}
		fmt.Fprintf(&ret, "  %s", codes)
	}
	ret.WriteString("\n} Opcode deriving (Bits, Eq, FShow);\n\n")

	allFields := map[string]bool{}
	ret.WriteString("typedef struct {\n")
	for _, f := range decoderStructFields(encodings) {
		allFields[f.Name] = true
		if f.Name == "op" {
			ret.WriteString("  Opcode op;\n")
		} else {
			fmt.Fprintf(&ret, "  UInt#(%d) %s;\n", f.Bits, strings.TrimPrefix(f.Name, "#"))
		}
	}
	ret.WriteString("} RawDecodedInstruction deriving (Bits, Eq, FShow);\n\n")

	fmt.Fprintf(&ret, "function RawDecodedInstruction parseInstruction(Bit#(%d) raw);\n", instructionWidth)
	fmt.Fprintf(&ret, "  return case (raw[%d:%d]) matches\n", instructionWidth-1, instructionWidth-1-largestPrefix)
	for _, e := range orderedEncodings(encodings) {
		fmt.Fprintf(&ret, "    'b%s%s: RawDecodedInstruction{\n", e.Prefix, strings.Repeat("?", largestPrefix-e.Prefix.Bits))
		startOff := instructionWidth - 1 - e.Prefix.Bits - e.FillerBits
		first := true
		writeField := func(msg string, args ...any) {
			if first {
				first = false
			} else {
				ret.WriteString(",\n")
			}
			fmt.Fprintf(&ret, msg, args...)
		}
		setFields := map[string]bool{}
		for _, f := range e.Fields {
			setFields[f.Name] = true
			endOff := startOff - f.Bits + 1
			n := strings.TrimPrefix(f.Name, "#")
			switch n {
			case "op":
				writeField("      op: case (UInt#(%d)'(unpack(raw[%d:%d]))) matches\n", f.Bits, startOff, endOff)
				for i, insn := range insns {
					if insn.Encoding != e {
						continue
					}
					fmt.Fprintf(&ret, "        %d: %s;\n", insn.Opcode, names[i])
				}
				ret.WriteString("      endcase")
			default:
				writeField("      %s: zeroExtend(unpack(raw[%d:%d]))", n, startOff, endOff)
			}
			startOff = endOff - 1
		}
		if !setFields["op"] {
			setFields["op"] = true
			for i, insn := range insns {
				if insn.Encoding != e {
					continue
				}
				writeField("      op: %s", names[i])
				break
			}
		}

		var unsetFields []string
		for n := range allFields {
			if !setFields[n] {
				unsetFields = append(unsetFields, strings.TrimPrefix(n, "#"))
			}
		}
		sort.Strings(unsetFields)
		for _, n := range unsetFields {
			writeField("      %s: ?", strings.TrimPrefix(n, "#"))
		}

		fmt.Fprintf(&ret, "\n    };\n")
	}
	ret.WriteString("  endcase;\n")
	ret.WriteString("endfunction\n\n")

	ret.WriteString("endpackage\n")
	return ret.Bytes()
}

func orderedEncodings(encodings map[shape]*encoding) []*encoding {
	var ret []*encoding
	for _, e := range encodings {
		ret = append(ret, e)
	}
	sort.Slice(ret, func(i, j int) bool {
		return ret[i].Name < ret[j].Name
	})
	return ret
}

func decoderStructFields(encodings map[shape]*encoding) []field {
	structParts := map[string]field{}
	for _, e := range encodings {
		for _, f := range e.Fields {
			if f.Bits > structParts[f.Name].Bits {
				structParts[f.Name] = *f
			}
		}
	}

	var structList []field
	for _, f := range structParts {
		structList = append(structList, f)
	}
	sort.Slice(structList, func(i, j int) bool {
		return structList[i].Name < structList[j].Name
	})
	return structList
}

func globalOpcodeNames(insns []*encodedInstruction) []string {
	var ret []string
	unqualifiedNames := map[string]int{}
	for _, insn := range insns {
		baseName := unqualifiedOpcodeName(insn)
		fullName := false
		if i, ok := unqualifiedNames[baseName]; ok {
			ret[i] = qualifiedOpcodeName(insns[i])
			fullName = true
		}
		if fullName {
			ret = append(ret, qualifiedOpcodeName(insn))
		} else {
			unqualifiedNames[baseName] = len(ret)
			ret = append(ret, baseName)
		}
	}
	return ret
}

func qualifiedOpcodeName(insn *encodedInstruction) string {
	return unqualifiedOpcodeName(insn) + "_" + strings.ToUpper(string(insn.Encoding.Name))
}

func unqualifiedOpcodeName(insn *encodedInstruction) string {
	return fmt.Sprintf("Op%s", strings.Title(insn.Raw.Name))
}
