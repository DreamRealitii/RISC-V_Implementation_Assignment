#.extern main
.globl _start

.data
v1:	.word	0       # printf port
v2: .word   0       # halt port

.text

_start:
    li      sp, 30000
    lw      x1, v1
    call    main
    call    halt
    j       _start
