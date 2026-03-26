main:
    addi x1, x0, 10
    addi x2, x0, 10

    beq  x1, x2, taken
    addi x3, x0, 111     # debe ser anulada si el branch se toma
    addi x4, x0, 222     # debe ser anulada si el branch se toma

taken:
    addi x5, x0, 55
