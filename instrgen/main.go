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

	arts := AsciiArt(encodings)

	for _, art := range arts {
		fmt.Println(art)
	}
}
