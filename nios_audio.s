.equ AUDIO, 0xFF203040 	   # (From DESL website > NIOS II > devices)
.equ JTAG_UART, 0XFF201000

.global _start
_start:
	#max ampliltude initialize
	movi r9, 0
	#number of samples needed to chech before update max amp
	movi r17, 384
	#local max amplitude withing the 384 samples
	movi r18, 0
	#the loop counter
	movi r15, 0
	
	#determine when to print to jtag
	movi r11, 0
	movi r12, 50
	main:
	movia r2, AUDIO
	ldwio r3, 4(r2)
	andi r3, r3, 0xff
	beq r3, r0, main
	ldwio r3, 8(r2)
	stwio r3, 8(r2)
	ldwio r3, 12(r2)
	stwio r3, 12(r2)
	
	#update the local max amplitude
	bgt r3, r18, updateLocalAmp
	returnFromLocalAmp:
	#incriment the loop counter
	addi r15, r15, 1
	
	#if enough loops have happened, update max amp and reset local amp
	bge r15, r17, updateMaxAmp
	returnFromMaxAmp:
	

	srli r10, r9, 23
	br main
	
	
	
	updateLocalAmp:
	mov r18, r3
	br returnFromLocalAmp
	
	updateMaxAmp:
	mov r9, r18
	movi r18, 0
	movi r15, 0
	
	addi r11, r11, 1
	bge r11, r12, printJTAG
	
	br returnFromMaxAmp
	
	
	printJTAG:
	mov r11, r0
	movia r20, JTAG_UART
	
	movui r19, 0x1b
	stwio r19, 0(r20)
	movui r19, 0x5b
	stwio r19, 0(r20)
	movui r19, 0x32
	stwio r19, 0(r20)
	movui r19, 0x4a
	stwio r19, 0(r20)
	
	movia r19, 0x0600000
	blt r9, r19, printS
	
	movia r19, 0x50000000
	blt r9, r19, printM
	
	
	movia r20, JTAG_UART
	movui r19, 0x4c
	stwio r19, 0(r20)
	br returnFromMaxAmp
	
	printS:
	movia r20, JTAG_UART
	movui r19, 0x53
	stwio r19, 0(r20)
	br returnFromMaxAmp
	
	printM:
	movia r20, JTAG_UART
	movui r19, 0x4d
	stwio r19, 0(r20)
	br returnFromMaxAmp
	