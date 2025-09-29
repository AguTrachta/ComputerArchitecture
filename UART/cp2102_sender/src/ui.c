#include "ui.h"
#include <stdlib.h>
#include <string.h>

void ui_init() {
    initscr();
    cbreak();
    noecho();
    keypad(stdscr, TRUE);
    curs_set(0);
    nodelay(stdscr, TRUE);   // <- getch() no bloquea
    timeout(200);            // <- máximo 200 ms de espera
}

void ui_end() {
    endwin();
}


Operation ui_get_operation(volatile sig_atomic_t *running) {
    const char *ops[] = {
        "ADD (suma)",
        "SUB (resta)",
        "AND (bitwise)",
        "OR  (bitwise)",
        "XOR (bitwise)",
        "SRA (shift right aritmético)",
        "SRL (shift right lógico)",
        "NOR (not OR)"
    };
    Opcode codes[] = {
        OP_ADD, OP_SUB, OP_AND, OP_OR,
        OP_XOR, OP_SRA, OP_SRL, OP_NOR
    };

    int total_ops = sizeof(codes) / sizeof(codes[0]);
    int choice = 0;
    int ch;

    // Menú de selección
    while (*running) {
        clear();
        mvprintw(0, 0, "Seleccione operación:");
        for (int i = 0; i < total_ops; i++) {
            if (i == choice) {
                attron(A_REVERSE);
                mvprintw(i+2, 2, "%s", ops[i]);
                attroff(A_REVERSE);
            } else {
                mvprintw(i+2, 2, "%s", ops[i]);
            }
        }
        mvprintw(12, 0, "Use flechas y ENTER para elegir.");
        refresh();

        ch = getch();
        if (ch == ERR) continue; // nada presionado

        switch (ch) {
            case KEY_UP:
                choice = (choice == 0) ? total_ops - 1 : choice - 1;
                break;
            case KEY_DOWN:
                choice = (choice == total_ops - 1) ? 0 : choice + 1;
                break;
            case 10: // ENTER
            {
                Operation op;
                op.opcode = codes[choice];

                // 🔹 limpiar buffer y bloquear entrada para scanw
                flushinp();
                timeout(-1);

                echo();
                curs_set(1);
                mvprintw(14, 0, "Ingrese operando A (0-255): ");
                scanw("%d", &op.A);
                mvprintw(15, 0, "Ingrese operando B (0-255): ");
                scanw("%d", &op.B);
                noecho();
                curs_set(0);

                // 🔹 restaurar timeout no bloqueante
                timeout(200);

                return op;
            }
        }
    }

    // Si salimos por Ctrl+C
    Operation dummy = {0};
    return dummy;
}

