#ifndef stream_client_h
#define stream_client_h

#include <ev.h>
#include <stdint.h>

typedef enum {
    SC_INIT = 0,
    SC_CONNECTING,
    SC_CONNECTED

} stream_client_state_t;

typedef struct {
    int fd;
    stream_client_state_t state;

    ev_io ev_read;
    ev_io ev_write;
    ev_io ev_timeout;

    void* error_callback;
    void* eof_callback;

    void* read_callback;
    void* connect_callback;
} stream_client_t;

typedef void (*stream_client_error_callback_f)(stream_client_t* client, int code, const char* msg);
typedef void (*stream_client_read_callback_f)(stream_client_t* client, const char* buf, int len);
typedef void (*stream_client_connect_callback_f)(stream_client_t* client);

stream_client_t* stream_client_init();
void stream_client_free(stream_client_t* client);

int stream_client_connect(stream_client_t* client, uint32_t host, uint16_t port);
int stream_client_disconnect(stream_client_t* client);

int stream_client_run_once(stream_client_t* client);

int stream_client_keepalive(stream_client_t* client);

#endif


