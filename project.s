#Conventions
#Functions will use caller saved registers r8, r9 first then callee saved registers
#Recall: VGA pixel offset requires adding 2*x + 1024*y
#"Global Variables"
#r22 is X location of center of the ball, r20 is X directionality
#r23 is Y location of center of the ball, r21 is Y directionality
#r16 is previous top of the left bar, r18 is the new top of the left bar
#r17 is previous top of the right bar, r19 is the new top of the right bar

#External Devices
.equ JTAG_UART, 0xFF201000
.equ old_time, 0xF08002FA #500M in Hex
.equ redraw_time, 0x05000000
.equ stuffedcow_time, x01000000
.equ VGA_PIXEL_BASE, 0x08000000
.equ VGA_CHAR_BASE, 0x09000000
.equ HEX_DISPLAY, 0xFF200020 #every 8 bits is a new HEX display until bit 30 (6-0 H0, 14-8 H1, 22-16 H2, 30-24 H3)
.equ AUDIO, 0XFF203040
.equ IRQ_SETUP, 0x00000001
.equ TIMER, 0xFF202000

#VGA Definitions
.equ XMAX, 320
.equ YMAX, 240
.equ BALL_START_X, 160
.equ BALL_START_Y, 120
.equ BAR1_START_X, 0
.equ BAR2_START_X, 318
.equ BAR1_START_Y, 114
.equ BAR2_START_Y, 114
.equ BAR_SIZE, 15
.equ WHITE, 0xFFFF
.equ GREY, 0x8410
.equ BLACK, 0x0000
.equ RED, 0xF800
.equ GREEN, 0x07E0
.equ BLUE, 0x001F
.equ PURPLE, 0xF81F

#ISR
.section .exceptions,"ax"
ISR:
	rdctl et, ipending #check ipending
	#Jumping if not timer interrupt
	andi et, et, 0x1
	beq et, r0, END_ISR

	#Start of Timer Interrupt Handling
	addi sp, sp, -4
	stw r8,(sp)
	call REDRAW_ICON
	call REDRAW_BAR
	#acknowledge interrupt and reset timer
	movia et, TIMER
	stwio r0, (et)
	movui r8, 0b101 #Enable start, no CTS, with interrupt
	stwio r8, 4(et)
	ldw r8,(sp)
	addi sp, sp, 4
	br END_ISR
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

movui r4, BLACK
call RESET_VGA

#Draw first bar
movui r4, WHITE
addi r5, r0, BAR1_START_X
addi r6, r0, BAR1_START_Y
call DRAW_BAR
addi r18,r0,BAR1_START_Y

#Draw second bar
movui r4, WHITE
addi r5, r0, BAR2_START_X
addi r6, r0, BAR2_START_Y
call DRAW_BAR
addi r18,r0,BAR2_START_Y

#Draw the ball
movui r4, GREEN
addi r5, r0, BALL_START_X
addi r6, r0, BALL_START_Y
call DRAW_ICON
movui r22, BALL_START_X
movui r23, BALL_START_Y
addi r20,r0,1
addi r21,r0,1

#END SETUP

#ISR_SETUP
	#Enable interrups
	movi r9, IRQ_SETUP
	wrctl ienable, r9 #ienable = ctl3
	movi r9, 0b1
	wrctl status, r9 #Enable PIE

	#Initialize counter value
	movia r8, TIMER
	movui r9, %lo(redraw_time)
	stwio r9, 8(r8)
	movui r9, %hi(redraw_time)
	stwio r9, 12(r8)

	stwio r0, (r8) #reset TIMER
	movui r9, 0b101 #Enable start, no CTS, enable interrupt
	stwio r9, 4(r8)
#END ISR_SETUP

gameLoop:


br gameLoop

#END: br END not necessary since the game loops in game loop

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

#Draw a 3x7 bar with color specified in r4, leftmost x location in r5, top y location in r6
DRAW_BAR:
	#Prologue
	addi sp, sp, -12
	stw ra,0(sp)
	stw r5,4(sp)
	stw r6,8(sp)
	
	#Initialization
	#Adjust arguments to center
	muli r5, r5, 2
	muli r6, r6, 1024
	add r6,r5,r6
	movia r5,VGA_PIXEL_BASE
	add r5,r5,r6
	
	#Core
	movui r6, BAR_SIZE
BAR_DRAWING_LOOP:
	call DRAW_BAR_SECTION
	addi r5,r5,1024
	addi r6,r6,-1
	bgt r6,r0,BAR_DRAWING_LOOP

	#Epliogue
	ldw ra,(sp)
	ldw r5,4(sp)
	ldw r6,8(sp)
	addi sp, sp, 12
	ret

#Function to draw a 3x1 line at a location specified by color=r4,location=r5
DRAW_BAR_SECTION:
	#Prologue (N/A)
	
	#Draw 3 bits
	sthio r4, (r5)
	sthio r4, 2(r5)
	sthio r4, 4(r5)
	
	#Epilogue (N/A)
	ret

#Function to redraw the bar
REDRAW_BAR:
	#Prologue
	addi sp, sp, -16
	stw ra,(sp)
	stw r4,4(sp)
	stw r5,8(sp)
	stw r6,12(sp)

	#Initialization
	movia r8, VGA_PIXEL_BASE

	#Redraw over old location
	movui r4, BLACK
	movui r5, BAR1_START_X
	mov r6, r16
	call DRAW_BAR
	movui r5, BAR2_START_X
	mov r6, r17
	call DRAW_BAR

	#Draw in new location
	movui r4, BLUE
	movui r5, BAR1_START_X
	mov r6, r18
	call DRAW_BAR
	movui r4, BLUE
	movui r5, BAR2_START_X
	mov r6, r19
	call DRAW_BAR

	#Update old and new
	add r16,r0,r18
	add r17,r0,r19

	#Epliogue
	ldw ra,(sp)
	ldw r4,4(sp)
	ldw r5,8(sp)
	ldw r6,12(sp)
	addi sp, sp, 16
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
	addi sp, sp, -16
	stw ra,(sp)
	stw r4,4(sp)
	stw r5,8(sp)
	stw r6,12(sp)

	#Initialization
	movia r8, VGA_PIXEL_BASE

	#Redraw over old location
	movui r4, BLACK
	mov r5, r22
	mov r6, r23
	call DRAW_ICON

	#Correct r22, r23 with border detection
	#Check X direction
	bgt r20,r0,MOVING_RIGHT
MOVING_LEFT:
	addi r22, r22, -1 
	br Y_DIR_CHECK
MOVING_RIGHT: 
	addi r22, r22, 1
Y_DIR_CHECK:
	bgt r21, r0, MOVING_DOWN
MOVING_UP:
	addi r23,r23, -1
	br BORDER_CHECK
MOVING_DOWN:
	addi r23, r23, 1
BORDER_CHECK:
	movui r4,XMAX
	#Check X border, Y border
	bge r22,r4,CHANGE_X_DIR
	ble r22,r0,CHANGE_X_DIR
	br CHECK_Y_DIR
CHANGE_X_DIR:
	xori r20,r20,1
CHECK_Y_DIR:
	movui r4,YMAX
	bge r23,r4,CHANGE_Y_DIR
	ble r23,r0,CHANGE_Y_DIR
	br END_CHANGE_DIR
CHANGE_Y_DIR:
	xori r21,r21,1

END_CHANGE_DIR:
	#Core
	movui r4, GREEN
	mov r5, r22
	mov r6, r23
	call DRAW_ICON
	
	#Epliogue
	ldw ra,(sp)
	ldw r4,4(sp)
	ldw r5,8(sp)
	ldw r6,12(sp)
	addi sp, sp, 16
	ret

#Function to write a value in r4 to the 7-seg display HEX0
DRAW_HEX0_DIGIT:
	#Prologue (N/A)
	
	#Initialization
	movia r8, HEX_DISPLAY
	
	#Core
	
	
	#Epilogue
	ret
