branch_test.s:
.align 4
.section .text
.globl _start
    # This program will provide a simple test for
    # demonstrating branching

    # This test is NOT exhaustive
_start:

# initialize
li x1, 0
li x2, 0
li x3, 30 #Only works 2 and under for some reason

nop
nop
nop
nop
nop
nop

loop:
    addi x2, x2, 10
    addi x1, x1, 1
    blt x1, x3, loop

halt:
    slti x0, x0, -256
