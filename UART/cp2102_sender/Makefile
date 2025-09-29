# Nombre del proyecto
TARGET = cp2102_sender

# Directorios
SRC_DIR = src
INC_DIR = include
BIN_DIR = bin

# Archivos fuente y objetos
SRCS = $(wildcard $(SRC_DIR)/*.c)
OBJS = $(SRCS:$(SRC_DIR)/%.c=$(BIN_DIR)/%.o)

# Compilador y flags
CC = gcc
CFLAGS = -Wall -Wextra -O2 -I$(INC_DIR) -pthread
LDLIBS = -lncurses

# Ejecutable final
EXEC = $(BIN_DIR)/$(TARGET)

# Regla por defecto
all: $(EXEC)

# Regla para crear el ejecutable
$(EXEC): $(OBJS)
	$(CC) $(CFLAGS) -o $@ $^ $(LDLIBS)

# Regla para compilar .c en .o
$(BIN_DIR)/%.o: $(SRC_DIR)/%.c | $(BIN_DIR)
	$(CC) $(CFLAGS) -c $< -o $@

# Crear carpeta bin si no existe
$(BIN_DIR):
	mkdir -p $(BIN_DIR)

# Limpieza
clean:
	rm -rf $(BIN_DIR)/*.o $(EXEC)

.PHONY: all clean
