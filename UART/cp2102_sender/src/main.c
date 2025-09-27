#include "serial.h"
#include "utils.h"
#include <errno.h>
#include <fcntl.h>
#include <glob.h>
#include <pthread.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/select.h>
#include <termios.h>
#include <unistd.h>

typedef struct {
  int fd;
} thread_args;

volatile sig_atomic_t running = 1;
volatile sig_atomic_t uart_configured = 0;

void *receiver_thread(void *arg) {
  thread_args *targs = (thread_args *)arg;
  char buffer[256];

  while (running) {
    int n = receive_data(targs->fd, buffer, sizeof(buffer));
    if (n > 0) {
      buffer[n] = '\0';
      printf("[UART RX]: %s\n", buffer);
      fflush(stdout);
    }
    usleep(100000); // 100ms
  }

  printf("[UART RX] Hilo finalizado.\n");
  return NULL;
}

void handle_sigint(int sig) {
  (void)sig;
  if (!uart_configured) {
    // todavía no configuraste nada → salida inmediata
    running = 0;
    printf(
        "\n[SALIDA] Se recibió Ctrl+C, cerrando antes de configuración...\n");
    exit(0); // ⚠️ salir ya mismo
  } else {
    // ya configurado → sólo marcar running = 0
    running = 0;
    printf("\n[SALIDA] Se recibió Ctrl+C, cerrando...\n");
  }
}

void print_usb_info(const char *device) {
  char cmd[256];
  snprintf(cmd, sizeof(cmd), "udevadm info -q all -n %s", device);

  FILE *fp = popen(cmd, "r");
  if (!fp)
    return;

  char line[256];
  char vendor[64] = "", product[64] = "", manufacturer[64] = "",
       serial[64] = "";

  while (fgets(line, sizeof(line), fp) != NULL) {
    if (strstr(line, "ID_VENDOR_ID=")) {
      sscanf(line, "E: ID_VENDOR_ID=%63s", vendor);
    } else if (strstr(line, "ID_MODEL_ID=")) {
      sscanf(line, "E: ID_MODEL_ID=%63s", product);
    } else if (strstr(line, "ID_VENDOR_FROM_DATABASE=")) {
      sscanf(line, "E: ID_VENDOR_FROM_DATABASE=%63[^\n]", manufacturer);
    } else if (strstr(line, "ID_MODEL_FROM_DATABASE=")) {
      sscanf(line, "E: ID_MODEL_FROM_DATABASE=%63[^\n]", serial);
    }
  }
  pclose(fp);

  printf("   Vendor: %s  Product: %s\n", vendor, product);
  if (strlen(manufacturer) > 0)
    printf("   Fabricante: %s\n", manufacturer);
  if (strlen(serial) > 0)
    printf("   Producto: %s\n", serial);
}

int listar_dispositivos(glob_t *glob_result) {
  char option[16];
  int choice = -1;

  while (running) {
    globfree(glob_result);
    glob("/dev/ttyUSB*", 0, NULL, glob_result);
    glob("/dev/ttyACM*", GLOB_APPEND, NULL, glob_result);

    if (glob_result->gl_pathc == 0) {
      printf("No se encontraron dispositivos seriales "
             "(/dev/ttyUSB* o /dev/ttyACM*)\n");
      printf("Presione [r] para reintentar: ");
      fflush(stdout);
      ssize_t n = read(STDIN_FILENO, option, sizeof(option) - 1);
      if (n == -1) {
        if (errno == EINTR && !running)
          return -1; // interrumpido con Ctrl+C
        continue;    // otro error
      }
      if (n == 0)
        continue; // EOF

      option[n] = '\0';
      if (option[0] == 'r' || option[0] == 'R')
        continue;
      continue;
    }

    printf("\nDispositivos encontrados:\n");
    for (size_t i = 0; i < glob_result->gl_pathc; i++) {
      printf("[%zu] %s\n", i, glob_result->gl_pathv[i]);
      print_usb_info(glob_result->gl_pathv[i]);
    }

    printf("Seleccione interfaz (número) o [r] para reintentar: ");
    fflush(stdout);
    ssize_t n = read(STDIN_FILENO, option, sizeof(option) - 1);
    if (n == -1) {
      if (errno == EINTR && !running)
        return -1; // interrumpido con Ctrl+C
      continue;    // otro error
    }
    if (n == 0)
      continue; // EOF

    option[n] = '\0';

    if (option[0] == 'r' || option[0] == 'R')
      continue;

    if (sscanf(option, "%d", &choice) == 1 && choice >= 0 &&
        (size_t)choice < glob_result->gl_pathc) {
      return choice; // ✅ índice válido
    }

    printf("Selección inválida.\n");
  }
}

void print_uart_config(int fd) {
  struct termios options;
  tcgetattr(fd, &options);

  printf("\n--- Configuración UART ---\n");
  speed_t ispeed = cfgetispeed(&options);
  printf("Baudrate: %d\n", (ispeed == B115200) ? 115200
                           : (ispeed == B9600) ? 9600
                                               : -1);

  printf("Bits de datos: ");
  switch (options.c_cflag & CSIZE) {
  case CS5:
    printf("5\n");
    break;
  case CS6:
    printf("6\n");
    break;
  case CS7:
    printf("7\n");
    break;
  case CS8:
    printf("8\n");
    break;
  }

  printf("Paridad: %s\n", (options.c_cflag & PARENB) ? "Sí" : "No");
  printf("Stop bits: %s\n", (options.c_cflag & CSTOPB) ? "2" : "1");
  printf("--------------------------\n\n");
}

void configurar_uart_interactivo(int fd) {
  struct termios options;
  tcgetattr(fd, &options);

  // Mostrar config actual
  printf("\n--- Configuración UART (actual) ---\n");
  speed_t ispeed = cfgetispeed(&options);
  printf("Baudrate: %d\n", (ispeed == B115200) ? 115200
                           : (ispeed == B9600) ? 9600
                                               : -1);

  printf("Bits de datos: ");
  switch (options.c_cflag & CSIZE) {
  case CS5:
    printf("5\n");
    break;
  case CS6:
    printf("6\n");
    break;
  case CS7:
    printf("7\n");
    break;
  case CS8:
    printf("8\n");
    break;
  }

  printf("Paridad: %s\n", (options.c_cflag & PARENB) ? "Sí" : "No");
  printf("Stop bits: %s\n", (options.c_cflag & CSTOPB) ? "2" : "1");
  printf("-----------------------------------\n");

  // Preguntar
  char option[8];
  printf("¿Desea [a]ceptar o [c]onfigurar? ");
  fflush(stdout);
  ssize_t n = read(STDIN_FILENO, option, sizeof(option) - 1);
  if (n <= 0) {
    if (errno == EINTR && !running)
      return; // interrumpido
    return;   // otro error → acepta por defecto
  }
  option[n] = '\0';

  if (option[0] == 'c' || option[0] == 'C') {
    int baud, bits, stop;
    char parity;

    printf("Ingrese baudrate (ej: 9600, 115200): ");
    scanf("%d", &baud);
    getchar();

    printf("Ingrese bits de datos (5,6,7,8): ");
    scanf("%d", &bits);
    getchar();

    printf("Paridad (n = none, e = even, o = odd): ");
    scanf(" %c", &parity);
    getchar();

    printf("Stop bits (1 o 2): ");
    scanf("%d", &stop);
    getchar();

    // Aplicar configuración
    cfsetispeed(&options, (baud == 115200) ? B115200 : B9600);
    cfsetospeed(&options, (baud == 115200) ? B115200 : B9600);

    options.c_cflag &= ~CSIZE;
    switch (bits) {
    case 5:
      options.c_cflag |= CS5;
      break;
    case 6:
      options.c_cflag |= CS6;
      break;
    case 7:
      options.c_cflag |= CS7;
      break;
    default:
      options.c_cflag |= CS8;
      break;
    }

    if (parity == 'e' || parity == 'E') {
      options.c_cflag |= PARENB;
      options.c_cflag &= ~PARODD;
    } else if (parity == 'o' || parity == 'O') {
      options.c_cflag |= PARENB;
      options.c_cflag |= PARODD;
    } else {
      options.c_cflag &= ~PARENB;
    }

    if (stop == 2)
      options.c_cflag |= CSTOPB;
    else
      options.c_cflag &= ~CSTOPB;

    tcsetattr(fd, TCSANOW, &options);

    printf("\nConfiguración UART actualizada ✅\n");
  } else {
    printf("Se usará la configuración por defecto ✅\n");
  }
}

void cleanup(int fd, glob_t *glob_result, pthread_t *rx_thread) {
  running = 0;
  if (rx_thread) {
    pthread_join(*rx_thread, NULL);
  }
  if (fd >= 0) {
    close(fd);
  }
  if (glob_result) {
    globfree(glob_result);
  }
  printf("Programa terminado correctamente ✅\n");
}

int main() {
  signal(SIGINT, handle_sigint);

  glob_t glob_result;
  int choice = listar_dispositivos(&glob_result);

  const char *device = glob_result.gl_pathv[choice];
  printf("Usando: %s\n", device);

  int fd = open_serial_port(device, 115200);
  if (fd < 0)
    return 1;

  configurar_uart_interactivo(fd);
  uart_configured = 1; // ✅ desde acá Ctrl+C ya no interrumpe configuración

  pthread_t rx_thread;
  thread_args args = {.fd = fd};
  pthread_create(&rx_thread, NULL, receiver_thread, &args);

  char input[256];

  printf(">> ");
  fflush(stdout);

  while (running) {

    fd_set set;
    struct timeval timeout;
    FD_ZERO(&set);
    FD_SET(STDIN_FILENO, &set);

    timeout.tv_sec = 1; // espera máximo 1s
    timeout.tv_usec = 0;

    int rv = select(STDIN_FILENO + 1, &set, NULL, NULL, &timeout);
    if (rv == -1) {
      if (errno == EINTR)
        continue; // interrumpido por señal
      perror("select");
      break;
    } else if (rv == 0) {
      // timeout → reintenta el while, chequea running
      continue;
    } else {
      ssize_t n = read(STDIN_FILENO, input, sizeof(input) - 1);
      if (n == -1) {
        if (errno == EINTR && !running)
          break;  // Ctrl+C
        continue; // otro error
      }
      if (n == 0)
        break; // EOF

      input[n] = '\0';
      if (strncmp(input, "exit", 4) == 0)
        break;

      send_data(fd, input);

      printf(">> ");
      fflush(stdout);
    }
  }

  cleanup(fd, &glob_result, &rx_thread);
  return 0;
}