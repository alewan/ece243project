.equ ADDR_JP2PORT, 0xFF200070
.equ ADDR_JP2PORT_DIR, 0xFF200074



.section .text
.global _start
_start:
  movia r2,ADDR_JP2PORT_DIR
  stwio r0,0(r2)  # Set direction of all 32-bits to input 
  movia r2,ADDR_JP2PORT
main:

  ldwio r3,(r2)   # Read value from pins
  movia r4, 0xFFFFFFFF
  bne r3, r4, AHA
  #andi r3, r3, 0x01

  br main
  
  AHA:
  mov r6, r3
  br main
