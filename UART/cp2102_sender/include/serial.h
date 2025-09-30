#ifndef SERIAL_H
#define SERIAL_H

#include <termios.h>
#include <stddef.h>

int open_serial_port(const char *device, int baudrate);
int send_data(int fd, const char *data, size_t len);
int receive_data(int fd, char *buffer, int buf_size);

#endif
