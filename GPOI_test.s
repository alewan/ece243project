.equ ADDR_JP2PORT, 0xFF200070
.equ ADDR_JP2PORT_DIR, 0xFF200074



.section .text
.global _start:
_start:
  movia r2,ADDR_JP2PORT_DIR
  stwio r0,0(r2)  # Set direction of all 32-bits to input 

main:
  movia r2,ADDR_JP2PORT
  ldwio r3,(r2)   # Read value from pins
  andi r3, r3, 0x01

  br main