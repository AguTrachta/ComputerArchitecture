#ifndef GLOBALS_H
#define GLOBALS_H

#include <pthread.h>
#include <signal.h>

extern pthread_mutex_t ui_mtx;
extern volatile sig_atomic_t ui_ready;

#endif
