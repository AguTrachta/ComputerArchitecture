#include "serial.h"
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

int open_serial_port(const char *device, int baudrate) {
  int fd = open(device, O_RDWR | O_NOCTTY | O_NDELAY);
  if (fd == -1) {
    perror("Error al abrir el puerto serial");
    return -1;
  }

  struct termios options;
  tcgetattr(fd, &options);

  // Configurar baudrate
  speed_t speed;
  switch (baudrate) {
  case 9600:
    speed = B9600;
    break;
  case 115200:
    speed = B115200;
    break;
  default:
    speed = B9600;
    break;
  }
  cfsetispeed(&options, speed);
  cfsetospeed(&options, speed);

  // 8N1
  options.c_cflag &= ~PARENB;
  options.c_cflag &= ~CSTOPB;
  options.c_cflag &= ~CSIZE;
  options.c_cflag |= CS8;

  options.c_cflag |= (CLOCAL | CREAD);                // Habilitar lectura
  options.c_lflag &= ~(ICANON | ECHO | ECHOE | ISIG); // Raw input
  options.c_iflag &= ~(IXON | IXOFF | IXANY);         // Sin control de flujo
  options.c_oflag &= ~OPOST;                          // Raw output

  options.c_cc[VMIN] = 0;  // no espera bytes mínimos
  options.c_cc[VTIME] = 1; // timeout de 0.1s

  tcsetattr(fd, TCSANOW, &options);

  return fd;
}

int send_data(int fd, const char *data, size_t len) {
    ssize_t n = write(fd, data, len);
    if (n < 0) {
        perror("Error enviando datos");
        return -1;
    }
    if ((size_t)n != len) {
        fprintf(stderr, "Advertencia: se enviaron %zd/%zu bytes\n", n, len);
    }
    return (int)n;
}

int receive_data(int fd, char *buffer, int buf_size) {
  int n = read(fd, buffer, buf_size - 1);
  if (n < 0) {
    if (errno == EAGAIN || errno == EWOULDBLOCK) {
      return 0; // no hay datos ahora
    }
    perror("Error leyendo datos");
    return -1;
  }
  buffer[n] = '\0';
  return n;
}
