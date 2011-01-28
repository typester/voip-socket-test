#include "stream_client.h"

#include <string.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <errno.h>
#include <assert.h>
#include <fcntl.h>
#include <netinet/in.h>
#include <netinet/tcp.h>
#include <sys/socket.h>
#include <unistd.h>

/* prototypes */
static void setup_sock(int fd);
static void change_state(stream_client_t* client, stream_client_state_t state);
static void read_callback(EV_P_ ev_io* w, int revents);
static void connect_callback(EV_P_ ev_io* w, int revents);

static void setup_sock(int fd) {
    int on = 1, r;

    r = setsockopt(fd, IPPROTO_TCP, TCP_NODELAY, &on, sizeof(on));
    assert(r == 0);
    r = fcntl(fd, F_SETFL, O_NONBLOCK);
    assert(r == 0);
}

static void change_state(stream_client_t* client, stream_client_state_t state) {
    struct ev_loop* loop = EV_DEFAULT;

    switch (state) {
        case SC_CONNECTED: {
            fprintf(stderr, "connect success\n");
            ev_io_init(&(client->ev_read), read_callback, client->fd, EV_READ);
            ev_io_start(EV_A_ &(client->ev_read));
            break;
        }
        default:
            break;
    }
    client->state = state;
}

static void read_callback(EV_P_ ev_io* w, int revents) {
    unsigned char buf[1024];
    int r;

    stream_client_t* client = (stream_client_t*)
        (((char*)w) - offsetof(stream_client_t, ev_read));

    stream_client_error_callback_f errcb;
    stream_client_read_callback_f cb;

    if (-1 == (r = read(client->fd, buf, 1024))) {
        if (errno == EAGAIN || errno == EINTR) return; /* try again */
        fprintf(stderr, "read error: %d %s\n", errno, strerror(errno));
        stream_client_disconnect(client);

        errcb = client->error_callback;
        if (NULL != errcb) {
            errcb(client, errno, strerror(errno));
        }
        return;
    }
    if (0 == r) {
        fprintf(stderr, "unexpected eof\n");
        stream_client_disconnect(client);

        errcb = client->eof_callback;
        if (NULL == errcb) errcb = client->error_callback;
        if (NULL != errcb) {
            errcb(client, errno, strerror(errno));
        }

        return;
    }

    buf[r] = '\0';

    fprintf(stderr, "read: %s\n", buf);

    cb = client->read_callback;
    if (NULL != cb) {
        cb(client, (const char*)buf, r + 1);
    }
}

static void connect_callback(EV_P_ ev_io* w, int revents) {
    ev_io_stop(EV_A_ w);

    stream_client_t* client = (stream_client_t*)
        (((char*)w) - offsetof(stream_client_t, ev_write));

    stream_client_error_callback_f cb = client->error_callback;

    if (SC_CONNECTING == client->state) {
        /* try to finish connect */
        int sock_err;
        socklen_t sock_err_len = sizeof(sock_err);

        if (0 != getsockopt(client->fd, SOL_SOCKET, SO_ERROR, &sock_err, &sock_err_len)) {
            fprintf(stderr, "getsockopt failed: %s\n", strerror(errno));
            stream_client_disconnect(client);

            if (NULL != cb) {
                cb(client, errno, strerror(errno));
            }
            return;
        }
        if (0 != sock_err) {
            fprintf(stderr, "establishing connection failed: %s\n", strerror(errno));
            stream_client_disconnect(client);

            if (NULL != cb) {
                cb(client, errno, strerror(errno));
            }
            return;
        }

        /* connect delayed succeeded */
        change_state(client, SC_CONNECTED);
    }
    else {
        fprintf(stderr, "wrong state %d on connect_callback\n", client->state);
        stream_client_disconnect(client);

        if (NULL != cb) {
            cb(client, 0, "wrong state");
        }
        return;
    }
}

stream_client_t* stream_client_init() {
    stream_client_t* client = calloc(1, sizeof(stream_client_t));
    return client;
}

void stream_client_free(stream_client_t* client) {
    if (0 != client->fd) {
        stream_client_disconnect(client);
    }
    free(client);
    client = NULL;
}

int stream_client_connect(stream_client_t* client, uint32_t host, uint16_t port) {
    assert(0 == client->fd);    /* not connected */

    int sock;
    struct ev_loop* loop = EV_DEFAULT;

    /* connect */
    sock = socket(AF_INET, SOCK_STREAM, 0);
    assert(-1 != sock);
    client->fd = sock;

    setup_sock(sock);

    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_port   = port;
    addr.sin_addr.s_addr = host;

    if (-1 != connect(sock, (struct sockaddr*)&addr, sizeof(addr))) {
        /* connect succeeded */
        change_state(client, SC_CONNECTED);
    }
    else {
        if (errno == EINPROGRESS || errno == EALREADY) {
            /* connect delayed */
            client->state = SC_CONNECTING;
            ev_io_init(&(client->ev_write), connect_callback, sock, EV_WRITE);
            ev_io_start(EV_A_ &(client->ev_write));
        }
        else {
            /* connect failed */
            fprintf(stderr, "connect failed: %d %s\n", errno, strerror(errno));
            stream_client_error_callback_f cb = client->error_callback;
            if (NULL != cb)
                cb(client, errno, strerror(errno));
            return -1;
        }
    }

    return 0;
}

int stream_client_disconnect(stream_client_t* client) {
    struct ev_loop* loop = EV_DEFAULT;
    ev_io_stop(EV_A_ &(client->ev_read));
    ev_io_stop(EV_A_ &(client->ev_write));
    close(client->fd);
    client->fd = client->state = 0;

    return 0;
}

int stream_client_keepalive(stream_client_t* client) {
    if (0 == client->fd) {
        fprintf(stderr, "connection already closed. try reconnect\n");
        return -1;
    }

 retry:
    if (-1 == write(client->fd, "keep-alive", 10)) {
        if (errno == EINTR || errno == EAGAIN) goto retry;

        fprintf(stderr, "failed to write keep-alive packet: %d %s\n", errno, strerror(errno));
        return -1;
    }

    return 0;
}

