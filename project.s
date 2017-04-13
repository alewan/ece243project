#Conventions
#Functions will use caller saved registers r8, r9 first then callee saved registers
#Recall: VGA pixel offset requires adding 2*x + 1024*y
#"Global Variables"
#r22 is X location of center of the ball, r20 is X directionality
#r23 is Y location of center of the ball, r21 is Y directionality
#r18 is the new top of the left bar
#r19 is the new top of the right bar
#r16 (Player 1) and r17 (Player 2) are the scores

#External Devices
.equ JTAG_UART, 0xFF201000
.equ old_time, 0xF08002FA #500M in Hex
.equ redraw_time, 0x00200000
.equ stuffedcow_time, x00100000
.equ VGA_PIXEL_BASE, 0x08000000
.equ VGA_CHAR_BASE, 0x09000000
.equ HEX_DISPLAY, 0xFF200020 #every 8 bits is a new HEX display until bit 30 (6-0 H0, 14-8 H1, 22-16 H2, 30-24 H3)
.equ AUDIO, 0XFF203040
.equ IRQ_SETUP, 0x00000003 #line0 for timer, line1 for keys
.equ TIMER1, 0xFF202000
.equ ADDR_JP2PORT, 0xFF200070
.equ ADDR_JP2PORT_DIR, 0xFF200074
.equ KEYS, 0xFF200050

#VGA Definitions
.equ XMAX, 320
.equ YMAX, 240
.equ BALL_START_X, 160
.equ BALL_START_Y, 120
.equ BAR1_START_X, 20
.equ BAR2_START_X, 290
.equ BAR1_START_Y, 114
.equ BAR2_START_Y, 114
.equ BAR_SIZE, 25
.equ WHITE, 0xFFFF
.equ GREY, 0x8410
.equ BLACK, 0x0000
.equ RED, 0xF800
.equ GREEN, 0x07E0
.equ BLUE, 0x001F
.equ PURPLE, 0xF81F

#Hex Definitions
.equ HEX_DISPLAY_VAL0, 0x3F
.equ HEX_DISPLAY_VAL1, 0x06
.equ HEX_DISPLAY_VAL2, 0x5B
.equ HEX_DISPLAY_VAL3, 0x4F
.equ HEX_DISPLAY_VAL4, 0x66
.equ HEX_DISPLAY_VAL5, 0x6D
.equ HEX_DISPLAY_VAL6, 0x6D
.equ HEX_DISPLAY_VAL7, 0x7D
.equ HEX_DISPLAY_VAL8, 0x07
.equ HEX_DISPLAY_VAL9, 0x7F
.equ HEX_DISPLAY_VALA, 0x6F


#TO SAVE IN THE ISR
#r8
#r9
#r10
#r11
#r12
#r13

#ISR
.section .exceptions,"ax"
ISR:
	rdctl et, ipending #check ipending
	#look for timer interrupt
	andi et, et, 0x1
	bne et, r0, TIMER_ISR
	rdctl et, ipending
	#look for key interrupt
	andi et, et, 0x2
	beq et, r0, END_ISR

KEYS_ISR:
	#Start of keys interrupt handling
	#acknowledge interrupt
	movia et, KEYS
	stwio r0, 12(et)
	#prevent future keys interrupts
	stwio r0, 8(et)
	#Exit to break the loop
	eret
	#End of keys interrupt handling

TIMER_ISR:
	#Start of Timer Interrupt Handling
	addi sp, sp, -40
	stw r8,(sp)
	stw r9,4(sp)
	stw r10,8(sp)
	stw r11,12(sp)
	stw r12,16(sp)
	stw r13,20(sp)
	stw r14,24(sp)
	stw r4,28(sp)
	stw r5,32(sp)
	stw r6,36(sp)
	

	#check the fsr
	movia r11, ADDR_JP2PORT_DIR
	stwio r0, 0(r11)
	movia r11, ADDR_JP2PORT
	ldwio r14, 0(r11)
	movia r12, 0xffffffff
	bne r14, r12, addr19
	br subr19
	retFromFSR:
	call REDRAW_ICON
	call REDRAW_BAR
	call UPDATE_SCORE
	#acknowledge interrupt and reset timer
	movia et, TIMER1
	stwio r0, (et)
	movui r8, 0b101 #Enable start, no CTS, with interrupt
	stwio r8, 4(et)
	ldw r8,(sp)
	ldw r9,4(sp)
	ldw r10,8(sp)
	ldw r11,12(sp)
	ldw r12,16(sp)
	ldw r13,20(sp)
	ldw r14,24(sp)
	ldw r4,28(sp)
	ldw r5,32(sp)
	ldw r6,36(sp)
	addi sp, sp, 40
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

#Initialize scores to zero
mov r16, r0
mov r17, r0

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
addi r19,r0,BAR2_START_Y

#Draw the ball
movui r4, GREEN
addi r5, r0, BALL_START_X
addi r6, r0, BALL_START_Y
call DRAW_ICON
movui r22, BALL_START_X
movui r23, BALL_START_Y
addi r20,r0,1
addi r21,r0,1

call UPDATE_SCORE
#END SETUP

#ISR_SETUP
	#Enable interrups
	movi r9, IRQ_SETUP
	wrctl ienable, r9 #ienable = ctl3
	movi r9, 0b1
	wrctl status, r9 #Enable PIE

	#Setup keys and then wait for keypress to start the game
	movia r8, KEYS
	movia r9,0x1
	stwio r9,8(r8)
	stwio r0,12(r8)
	#MESSGAE TO VGA BEFORE START OF GAME
	WAIT_FOR_KEYPRESS: br WAIT_FOR_KEYPRESS


	#Initialize counter value
	movia r8, TIMER1
	movui r9, %lo(redraw_time)
	stwio r9, 8(r8)
	movui r9, %hi(redraw_time)
	stwio r9, 12(r8)

	stwio r0, (r8) #reset TIMER1
	movui r9, 0b101 #Enable start, no CTS, enable interrupt
	stwio r9, 4(r8)
#END ISR_SETUP

#number of samples needed
movi r8, 384

#local max within the loop
movi r9, 0

#the loop counter
movi r10, 0


#TO SAVE IN THE ISR
#r8
#r9
#r10
#r11
#r12
#r13
#r14

gameLoop:

checkAudio:
#check if the fifo has anything in it
movia r11, AUDIO
ldwio r12, 4(r11)
andi r12, r12, 0xFF
beq r12, r0, checkAudio

#echo audio to the speakers (stored in r12)
ldwio r12, 8(r11)
stwio r12, 8(r11)
ldwio r12, 12(r11)
stwio r12, 12(r11)

#update the local max amplitude
bgt r12, r9, updateLocalAmp
returnFromLocalAmp:

#incriment the loop counter
addi r10, r10, 1

#if enough loops, then update the global max amplitude
bge r10, r8, updateMaxAmp
returnFromMaxAmp:


br gameLoop

#add to r19
addr19:
movi r12, 190
bgt r19, r12, retFromFSR
addi r19, r19, 5
br retFromFSR

#sub from r19
subr19:
blt r19, r0, retFromFSR
subi r19, r19, 5
br retFromFSR

#update the max amplitude within the loop
updateLocalAmp:
mov r9, r12
br returnFromLocalAmp 

updateMaxAmp:
movi r10, 0
#temp register for shifting
mov r13, r9
srli r13, r13, 23
movi r9, 0

#maybe later here make it stay below 240
mov r18, r13
br returnFromMaxAmp

#END: br END not necessary since the game loops in game loop

#Function to reset VGA to colour specified in r4
RESET_VGA:
	#Prologue
	addi sp, sp, -8
	stw r10,0(sp)
	stw r11,4(sp)

	#Initialization
	movia r8, VGA_PIXEL_BASE
	mov r11, r0 #ycount
	
	#Core
	VGAR_Y_LOOP:
		mov r10, r0 #xcount
		movui r9, XMAX
		VGAR_X_LOOP:
			sthio r4,(r8)
			addi r8,r8,2
			addi r10, r10, 1
			blt r10, r9, VGAR_X_LOOP
		subi r8, r8, 640 #2*XMAX
		addi r8, r8, 1024
		addi r11, r11, 1
		movui r9, YMAX
		blt r11, r9, VGAR_Y_LOOP
	
	#Epilogue
	ldw r10,0(sp)
	ldw r11,4(sp)
	addi sp, sp, 8
	ret

#Draw over the column with color specified in r4, leftmost x location in r5
CLEAR_BAR_COLUMN:
	#Prologue
	addi sp, sp, -4
	stw ra,0(sp)
	
	#Initialization
	#Adjust arguments to center
	muli r5, r5, 2
	add r6,r5,r0
	movia r5,VGA_PIXEL_BASE
	add r5,r5,r6
	
	#Core
	movui r6, 240
CLEAR_BAR_DRAWING_LOOP:
	call DRAW_BAR_SECTION
	addi r5,r5,1024
	addi r6,r6,-1
	bgt r6,r0,CLEAR_BAR_DRAWING_LOOP

	#Epliogue
	ldw ra,(sp)
	addi sp, sp, 4
	ret

#Draw an arbitrarily sized bar with color specified in r4, leftmost x location in r5, top y location in r6
DRAW_BAR:
	#Prologue
	addi sp, sp, -4
	stw ra,0(sp)
	
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
	addi sp, sp, 4
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
	addi sp, sp, -4
	stw ra,(sp)

	#Initialization
	movia r8, VGA_PIXEL_BASE

	#Redraw over old location
	movui r4, BLACK
	movui r5, BAR1_START_X
	call CLEAR_BAR_COLUMN
	movui r5, BAR2_START_X
	call CLEAR_BAR_COLUMN

	#Draw in new location
	movui r4, BLUE
	movui r5, BAR1_START_X
	mov r6, r18
	call DRAW_BAR
	movui r4, BLUE
	movui r5, BAR2_START_X
	mov r6, r19
	call DRAW_BAR

	#Epliogue
	ldw ra,(sp)
	addi sp, sp, 4
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
	#Check X direction
	bgt r20,r0,MOVING_RIGHT
MOVING_LEFT:
	addi r22, r22, -2 
	br Y_DIR_CHECK
MOVING_RIGHT: 
	addi r22, r22, 2
Y_DIR_CHECK:
	bgt r21, r0, MOVING_DOWN
MOVING_UP:
	addi r23,r23, -2
	br BORDER_CHECK
MOVING_DOWN:
	addi r23, r23, 2
BORDER_CHECK:
	#Check for the left bar
	movui r4, BAR1_START_X
	addi r4,r4,4
	bgt r22,r4,DONE_CHECK_HIT_B1
	blt r23,r18, DONE_CHECK_HIT_B1
	addi r4,r18,BAR_SIZE
	bgt r23,r4,DONE_CHECK_HIT_B1
	#Getting here implies a hit on the bar
	xori r20,r20,1
	br CHECK_Y_DIR
DONE_CHECK_HIT_B1:
	#Check for the right bar
	movui r4, BAR2_START_X
	subi r4,r4,1
	blt r22,r4,DONE_CHECK_HIT_B2
	blt r23,r19, DONE_CHECK_HIT_B2
	addi r4,r19,BAR_SIZE
	bgt r23,r4,DONE_CHECK_HIT_B2
	#Getting here implies a hit on the bar
	xori r20,r20,1
	br CHECK_Y_DIR
DONE_CHECK_HIT_B2:
	#Check for the wall
	movui r4,XMAX
	#Check X border, Y border
	bge r22,r4,CHANGE_X_DIR_GOALP1
	ble r22,r0,CHANGE_X_DIR_GOALP2
	br CHECK_Y_DIR
CHANGE_X_DIR_GOALP1:
	addi r16,r16,1
	br CHANGE_X_DIR
CHANGE_X_DIR_GOALP2:
	addi r17,r17,1
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
	addi sp, sp, 4
	ret

#Function to write a value in r16 to the 7-seg display HEX0 and r17 to HEX1
UPDATE_SCORE:
	#Prologue (N/A)

	#Initialization
	movia r8, HEX_DISPLAY
	
	#Core
	#Check value in r16
	beq r16, r0, DRAW0_P1
	addi r9,r0,1
	beq r16, r9, DRAW1_P1
	addi r9,r9,1
	beq r16, r9, DRAW2_P1
	addi r9,r9,1
	beq r16, r9, DRAW3_P1
	addi r9,r9,1
	beq r16, r9, DRAW4_P1
	addi r9,r9,1
	beq r16, r9, DRAW5_P1
	addi r9,r9,1
	beq r16, r9, DRAW6_P1
	addi r9,r9,1
	beq r16, r9, DRAW7_P1
	addi r9,r9,1
	beq r16, r9, DRAW8_P1
	addi r9,r9,1
	beq r16, r9, DRAW9_P1
	addi r9,r9,1
	beq r16, r9, DRAWA_P1

#Update the score
DRAW0_P1:
	movui r9, HEX_DISPLAY_VAL0
	br UPDATE_P2
DRAW1_P1:
	movui r9, HEX_DISPLAY_VAL1
	br UPDATE_P2
DRAW2_P1:
	movui r9, HEX_DISPLAY_VAL2
	br UPDATE_P2
DRAW3_P1:
	movui r9, HEX_DISPLAY_VAL3
	br UPDATE_P2
DRAW4_P1:
	movui r9, HEX_DISPLAY_VAL4
	br UPDATE_P2
DRAW5_P1:
	movui r9, HEX_DISPLAY_VAL5
	br UPDATE_P2
DRAW6_P1:
	movui r9, HEX_DISPLAY_VAL6
	br UPDATE_P2
DRAW7_P1:
	movui r9, HEX_DISPLAY_VAL7
	br UPDATE_P2
DRAW8_P1:
	movui r9, HEX_DISPLAY_VAL8
	br UPDATE_P2
DRAW9_P1:
	movui r9, HEX_DISPLAY_VAL9
	br UPDATE_P2
DRAWA_P1:
	movui r9, HEX_DISPLAY_VALA
	stwio r9,(r8)
	#GAMEOVER
	movia ea, _start
	eret

UPDATE_P2:
	stwio r9,(r8) #Sending P1 score to hex display
	addi r8,r8,8
#Check value in r17
	beq r17, r0, DRAW0_P2
	addi r9,r0,1
	beq r17, r9, DRAW1_P2
	addi r9,r9,1
	beq r17, r9, DRAW2_P2
	addi r9,r9,1
	beq r17, r9, DRAW3_P2
	addi r9,r9,1
	beq r17, r9, DRAW4_P2
	addi r9,r9,1
	beq r17, r9, DRAW5_P2
	addi r9,r9,1
	beq r17, r9, DRAW6_P2
	addi r9,r9,1
	beq r17, r9, DRAW7_P2
	addi r9,r9,1
	beq r17, r9, DRAW8_P2
	addi r9,r9,1
	beq r17, r9, DRAW9_P2
	addi r9,r9,1
	beq r17, r9, DRAWA_P2

DRAW0_P2:
	movui r9, HEX_DISPLAY_VAL0
	br END_UPDATE_SCORE
DRAW1_P2:
	movui r9, HEX_DISPLAY_VAL1
	br END_UPDATE_SCORE
DRAW2_P2:
	movui r9, HEX_DISPLAY_VAL2
	br END_UPDATE_SCORE
DRAW3_P2:
	movui r9, HEX_DISPLAY_VAL3
	br END_UPDATE_SCORE
DRAW4_P2:
	movui r9, HEX_DISPLAY_VAL4
	br END_UPDATE_SCORE
DRAW5_P2:
	movui r9, HEX_DISPLAY_VAL5
	br END_UPDATE_SCORE
DRAW6_P2:
	movui r9, HEX_DISPLAY_VAL6
	br END_UPDATE_SCORE
DRAW7_P2:
	movui r9, HEX_DISPLAY_VAL7
	br END_UPDATE_SCORE
DRAW8_P2:
	movui r9, HEX_DISPLAY_VAL8
	br END_UPDATE_SCORE
DRAW9_P2:
	movui r9, HEX_DISPLAY_VAL9
	br END_UPDATE_SCORE
DRAWA_P2:
	movui r9, HEX_DISPLAY_VALA
	stwio r9,(r8)
	#GAMEOVER
	movia ea, _start
	eret

END_UPDATE_SCORE:
	stwio r9,(r8) #Sending P2 score to hex display
	#Epilogue (N/A)
	ret
