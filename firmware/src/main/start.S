

    .section .init;
    .globl _start;
    .type _start,@function

_start:
	li x1,1
	li x2,2
	li x3,3
	li x4,4
	li x5,5
	j _start
    