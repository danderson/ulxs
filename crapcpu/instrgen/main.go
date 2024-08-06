package main

import (
	"fmt"
	"os"
)

func fatal(msg string, args ...any) {
	fmt.Fprintf(os.Stderr, msg+"\n", args...)
	os.Exit(1)
}

func main() {
	insns, pragmas, err := parse(os.Args[1])
	if err != nil {
		fatal("parsing instruction definitions: %v", err)
	}

	encodings := computeEncodings(insns, pragmas.InstructionBits, log2ceil(pragmas.NumRegisters))

	//arts := AsciiArt(encodings)

	assigned := assignInstructions(insns, encodings)
	decoder := genDecoder(assigned, encodings, pragmas.InstructionBits)

	prog, err := parseAsm(os.Args[2])
	if err != nil {
		fatal("parsing asm: %v", err)
	}

	compiled, err := assemble(prog, assigned)
	if err != nil {
		fatal("assembling program: %v", err)
	}

	_ = decoder
	fmt.Println(string(compiled))
	if err := os.WriteFile("RawDecoder.bsv", decoder, 0644); err != nil {
		fatal("writing decoder: %v", err)
	}
	if err := os.WriteFile(os.Args[3], compiled, 0644); err != nil {
		fatal("writing decoder: %v", err)
	}
}
