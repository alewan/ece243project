#Conventions
#Functions will use caller saved registers r8, r9 first then callee saved registers
#Recall: VGA pixel offset requires adding 2*x + 1024*y
#r22 is X location of center of the ball
#r23 is Y location of center of the ball
#Key is used as a global reset

#External Devices
.equ JTAG_UART, 0xFF201000
.equ old_time, 0xF08002FA #500M in Hex
.equ redraw_time, 0x05000000
.equ VGA_PIXEL_BASE, 0x08000000
.equ VGA_CHAR_BASE, 0x09000000
.equ HEX_DISPLAY, 0xFF200020 #every 8 bits is a new HEX display until bit 30 (6-0 H0, 14-8 H1, 22-16 H2, 30-24 H3)
.equ AUDIO, 0XFF203040
.equ IRQ_SETUP, 0x00000003 #line1 for pushbuttons, line0 for timer
.equ TIMER, 0xFF202000
.equ KEYS, 0xFF200050

#VGA Definitions
.equ XMAX, 320
.equ YMAX, 240
.equ WHITE, 0xFFFF
.equ GREY, 0x8410
.equ BLACK, 0x0000
.equ RED, 0xF800
.equ GREEN, 0x07E0
.equ BLUE, 0x001F
.equ PURPLE, 0xF81F

.section .exceptions,"ax"
ISR:
	#Mask and check for device that triggered the interrupt
	rdctl et, ipending #check ipending
	andi et, et, 0x10
	bne et, r0, START_KEYS_ISR
	andi et, et, 0x1
	bne et, r0, START_TIMER_ISR
	br END_ISR

START_KEYS_ISR:
	#Start of Keys Interrupt Handling
	#Note: clobbering registers doesn't matter here since we are going back to the start
	#Acknowledge interrupt 
	movia et, KEYS
	stwio r0, 12(et)
	movui ea, ON_RESET
	#Stop timer to avoid interrupt during reset
	movia et, TIMER
	movui r8, 0b1000 #Enable start, no CTS, with interrupt
	stwio r8, 4(et)
	eret
	#End of Keys Interrupt Handling

START_TIMER_ISR:
	#Start of Timer Interrupt Handling
	addi sp, sp, -4
	stw r8,(sp)
	call REDRAW_ICON
	#acknowledge interrupt and reset timer
	movia et, TIMER
	stwio r0, (et)
	movui r8, 0b101 #Enable start, no CTS, with interrupt
	stwio r8, 4(et)
	ldw r8,(sp)
	addi sp, sp, 4
	#br END_ISR (this is implicit)
	#End of Timer Interrupt Handling

END_ISR:
	addi ea, ea, -4
	eret

.section .text
.global _start
#Main code
_start:
#BEGIN SETUP
movia sp, 0x04000000

#Interrupt Setup
	#Set up push key reset
	movia r8,KEYS
	#Set only KEY[0] for interrupt
  	movia r9,0x1
  	stwio r9,8(r8)
  	stwio r0,12(r2) #Clear edge capture reg to avoid unwanted interrupt

	#Enable interrups
	movi r9, IRQ_SETUP
	wrctl ienable, r9 #ienable = ctl3
	movi r9, 0b1
	wrctl status, r9 #Enable PIE
#END Interrupt Setup

ON_RESET:
	movui r4, BLACK
	call RESET_VGA

	#Draw first bar
	movui r4, WHITE
	addi r5, r0, 1
	addi r6, r0, 117
	call DRAW_HALFBAR
	addi r5, r0, 1
	addi r6, r0, 123
	call DRAW_HALFBAR

	#Draw second bar
	movui r4, WHITE
	addi r5, r0, 319
	addi r6, r0, 117
	call DRAW_HALFBAR
	addi r5, r0, 319
	addi r6, r0, 123
	call DRAW_HALFBAR

	#Draw the ball
	movui r4, GREEN
	addi r5, r0, 160
	addi r6, r0, 120
	call DRAW_ICON
	movui r22, 160
	movui r23, 120

	#Timer Initialization
	movia r8, TIMER
	movui r9, %lo(redraw_time)
	stwio r9, 8(r8)
	movui r9, %hi(redraw_time)
	stwio r9, 12(r8)

	stwio r0, (r8) #reset TIMER
	movui r9, 0b101 #Enable start, no CTS, enable interrupt
	stwio r9, 4(r8)
	#End Timer Initialization
#END SETUP

END: br END

#Function to reset VGA to colour specified in r4
RESET_VGA:
	#Prologue
	addi sp, sp, -8
	stw r16,0(sp)
	stw r17,4(sp)

	#Initialization
	movia r8, VGA_PIXEL_BASE
	mov r17, r0 #ycount
	
	#Core
	VGAR_Y_LOOP:
		mov r16, r0 #xcount
		movui r9, XMAX
		VGAR_X_LOOP:
			sthio r4,(r8)
			addi r8,r8,2
			addi r16, r16, 1
			blt r16, r9, VGAR_X_LOOP
		subi r8, r8, 640 #2*XMAX
		addi r8, r8, 1024
		addi r17, r17, 1
		movui r9, YMAX
		blt r17, r9, VGAR_Y_LOOP
	
	#Epilogue
	ldw r16,0(sp)
	ldw r17,4(sp)
	addi sp, sp, 8
	ret

#Function to draw 3x6 bar at a location specified by x=r5, y=r6, color=r4
DRAW_HALFBAR:
	#Prologue (N/A)
	
	#Initialization
	movia r8, VGA_PIXEL_BASE
	
	#Core
	#Adjust r8 to center
	muli r5, r5, 2
	muli r6, r6,1024
	add r8, r8, r5
	add r8, r8, r6
	addi r8, r8, -1026 #Start at top LH corner (center-1026)
	
	#Top three bits
	sthio r4, (r8)
	sthio r4, 2(r8)
	sthio r4, 4(r8)
	
	#Middle three bits
	sthio r4, 1024(r8)
	sthio r4, 1026(r8)
	sthio r4, 1028(r8)	
	
	#Another three bits
	sthio r4, 2048(r8)
	sthio r4, 2050(r8)
	sthio r4, 2052(r8)

	#Yet another three bits
	sthio r4, 3072(r8)
	sthio r4, 3074(r8)
	sthio r4, 3076(r8)

	#Yet another three bits
	sthio r4, 4096(r8)
	sthio r4, 4098(r8)
	sthio r4, 4100(r8)

	#Last three bits
	sthio r4, 5120(r8)
	sthio r4, 5122(r8)
	sthio r4, 5124(r8)
	
	#Epliogue (N/A)
	ret
	
#Function to draw 3x3 icon at a location specified by x=r5, y=r6, color=r4
DRAW_ICON:
	#Prologue (N/A)
	
	#Initialization
	movia r8, VGA_PIXEL_BASE
	
	#Core
	#Adjust r8 to center
	muli r5, r5, 2
	muli r6, r6,1024
	add r8, r8, r5
	add r8, r8, r6
	addi r8, r8, -1026 #Start at top LH corner (center-1026)
	
	#Top three bits
	sthio r4, (r8)
	sthio r4, 2(r8)
	sthio r4, 4(r8)
	
	#Middle three bits
	sthio r4, 1024(r8)
	sthio r4, 1026(r8)
	sthio r4, 1028(r8)	
	
	#Bottom three bits
	sthio r4, 2048(r8)
	sthio r4, 2050(r8)
	sthio r4, 2052(r8)
	
	#Epliogue (N/A)
	ret


#Function to re-draw 3x3 icon at a location
REDRAW_ICON:
	#Prologue
	addi sp, sp, -4
	stw ra,(sp)

	#Initialization
	movia r8, VGA_PIXEL_BASE

	#Redraw over old location
	movui r4, BLACK
	mov r5, r22
	mov r6, r23
	call DRAW_ICON

	#Correct r22, r23 with border detection
	addi r22, r22, 1
	addi r23, r23, 1
	
	#Core
	movui r4, GREEN
	mov r5, r22
	mov r6, r23
	call DRAW_ICON
	
	#Epliogue
	ldw ra,(sp)
	addi sp, sp, 4
	ret

#Function to write a value in r4 to the 7-seg display HEX0
DRAW_HEX0_DIGIT:
	#Prologue (N/A)
	
	#Initialization
	movia r8, 0xFF200020
	
	#Core
	
	
	#Epilogue
	ret
	