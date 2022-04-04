	ldi r0,#42
	addi r2,r2,#1
	sub r1,r1,r2
	ldi r7,#64
	st r0,[r1,#0]
	j r7,#0
