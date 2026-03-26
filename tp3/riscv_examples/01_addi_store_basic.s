main:
    addi x1, x0, 11
    addi x2, x0, 22
    addi x3, x0, 33
    addi x4, x0, 44

    sw   x1, 0(x0)
    sw   x2, 4(x0)
    sw   x3, 8(x0)
    sw   x4, 12(x0)
