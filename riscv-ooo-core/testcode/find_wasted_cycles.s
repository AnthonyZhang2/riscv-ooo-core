find_wasted_cycles.s:
.align 4
.section .text
.globl _start

_start:

# initialize
li x1, 10
li x2, 20
li x5, 50
li x6, 60
li x8, 21
li x9, 28
li x11, 8
li x12, 4
li x14, 3
li x15, 1


# lui x1, 0xbb55A
la x1, some_data_1
lw x2, 0(x1)
lw x3, 4(x1)
lw x4, 8(x1)
lw x5, 12(x1)
lw x2, 0(x1)
lw x3, 4(x1)
lw x4, 8(x1)
lw x5, 12(x1)
lw x6, 16(x1)
lw x7, 20(x1)
lw x8, 24(x1)
lw x9, 28(x1)




halt:
    slti x0, x0, -256

.section .data
some_data_1:
    .word   0xAA552333
    .word 1, 2, 3, 4, 5, 6, 7, 8, 9
some_data_2:
    .half   0x0000
    .byte   0x00
    .byte   0x00