main:
    addi x1, x0, 99
    sw   x1, 0(x0)

    lw   x2, 0(x0)
    add  x3, x2, x2      # dependencia inmediata con el lw
    addi x4, x3, 1       # 199
