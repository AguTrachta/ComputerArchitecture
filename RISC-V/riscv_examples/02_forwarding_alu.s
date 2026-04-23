main:
    addi x1, x0, 5
    addi x2, x0, 7

    add  x3, x1, x2      # 12
    sub  x4, x3, x1      # 7  (depende de x3)
    and  x5, x4, x2      # 7  (depende de x4)
    or   x6, x5, x1      # 7  (depende de x5)
    xor  x7, x6, x2      # 0  (depende de x6)
