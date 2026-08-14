
.globl my_func
.globl _double

.section	.rodata
.align	2
.LC0:
    .string "%x\n"

.extern printf
.text

_double:
my_func:
    # Equivalent to printf("%x\n", 2 + 3)
    addi sp, sp, -12
    sw   ra, 4(sp)
    lui  a5,%hi(.LC0)
    addi a0,a5,%lo(.LC0)
    li   t0, 2
    li   t1, 3
    add  a1, t0, t1
    call printf
    lw   ra, 4(sp)
    addi sp, sp, 12
    ret
 
