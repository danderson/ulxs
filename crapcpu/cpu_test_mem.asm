	ldi r0,#1
	ldi r1,#0
	sub r1,r1,r0
loop:
	ld r0,[r1,#0]
	addi r0,r0,#10
	st r0,[r1,#0]
	ldi r0,test
test:
	j r0,#0
