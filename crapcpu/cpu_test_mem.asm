	ldi r0,#1
	ldi r1,#0
	sub r1,r1,r0
	ld r0,[r1,#0]
	addi r0,r0,#10
	st r0,[r1,#0]
	ldi r0,#14
	j r0,#0
