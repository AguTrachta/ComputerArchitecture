#ifndef UI_H
#define UI_H

#include <ncurses.h>
#include <signal.h>
#include <stdio.h>

// Opcodes que entiende la FPGA
typedef enum {
    OP_ADD = 0x20, // 100000
    OP_SUB = 0x22, // 100010
    OP_AND = 0x24, // 100100
    OP_OR  = 0x25, // 100101
    OP_XOR = 0x26, // 100110
    OP_SRA = 0x03, // 000011
    OP_SRL = 0x02, // 000010
    OP_NOR = 0x27  // 100111
} Opcode;

typedef struct {
    Opcode opcode;
    int A;
    int B;
} Operation;

// Inicializa ncurses
void ui_init();

// Limpia ncurses
void ui_end();

// Muestra menú y devuelve la operación seleccionada
Operation ui_get_operation(volatile sig_atomic_t *running);

#endif
