split_lsq_test.s:
.align 4
.section .text
.globl _start

_start:


lui x1, 0xAAAAB # start of data section, x1 = aaaa_b000
lb x2, 0(x1)    # bring cacheline in
mv x3, x1       # x3 = aaaa_b000
addi x4, x0, 1  # x4 = 1
nop             # nop "bubbles" fill the rest of the cacheline
nop
nop
nop

mul x1, x1, x4  # cascade multiplications so that x1 isn't ready for a while
mul x1, x1, x4  # these are just doing x1 = x1 * 1
mul x1, x1, x4
mul x1, x1, x4
mul x1, x1, x4
lb x7, 0(x1)    # this load should go on CDB after the next 2, since x1 won't be ready until the multiplications complete
lb x8, 0(x3)    # however, x3 will be ready as soon as the mv instruction completes
lb x9, 2(x3)


halt:
    slti x0, x0, -256

.section .data
    .word   0xAA552333