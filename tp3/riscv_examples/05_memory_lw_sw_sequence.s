main:
    addi x1, x0, 1
    addi x2, x0, 2
    addi x3, x0, 3
    addi x4, x0, 4

    sw   x1, 0(x0)
    sw   x2, 4(x0)
    sw   x3, 8(x0)
    sw   x4, 12(x0)

    lw   x5, 0(x0)
    lw   x6, 4(x0)
    lw   x7, 8(x0)
    lw   x8, 12(x0)
