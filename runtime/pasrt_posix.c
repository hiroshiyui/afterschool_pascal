/* Afterschool Pascal -- an ISO 7185 / ISO/IEC 10206:1991 Pascal compiler.
 * Copyright (C) 2026 Hui-Hong You
 *
 * This program is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option)
 * any later version.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
 * or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
 * for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

/* The part of the runtime that needs POSIX *types*, and the whole of it.
 *
 * `runtime/pasrt.c` is strict ISO C apart from a catalogue of function names
 * (ADR-0161), and that catalogue can only ever hold functions: it is proved
 * complete by stripping the non-ISO includes and requiring what is left to
 * compile, and a name that is a *type* cannot be excused that way -- an
 * incomplete `struct stat` is an error no flag silences. So `stat` could not
 * go there however well it was argued for, and this file is where ADR-0186 put
 * it instead.
 *
 * **The split is what makes the porting surface readable rather than smaller.**
 * The measurement ADR-0161 exists to keep honest is "what does a port to
 * another C library have to supply", and the answer now has two parts: eight
 * function names in pasrt.c, and this file entire. That is a worse headline
 * and a better description, because a POSIX dependency needing a type was
 * always going to be a different kind of thing from one needing a symbol.
 *
 * The rules for this file:
 *
 *   - Nothing the *compiler* emits calls into here. Everything is `pasx_`,
 *     which is the prefix a Pascal program may bind by name (ADR-0131), so
 *     a system without these calls loses library routines and not the
 *     language.
 *   - Every non-ISO header it includes is named in
 *     tests/checks/nonstandard_c.txt, and `runtime-isoc` fails in both
 *     directions over that list.
 *   - It stays small. What belongs here is what a *library module* cannot ask
 *     C for itself, which is a struct whose layout differs between systems
 *     (ADR-0185); everything a program can declare and check, it should.
 */

#include <dirent.h>
#include <errno.h>
#include <netdb.h>
#include <signal.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <unistd.h>

/* What a file *is*, for a library module that may not ask C directly.
 *
 * ADR-0184 lets a program declare a foreign struct and cross it; ADR-0185's
 * fifth decision is that a **library** may not, and this routine is the other
 * side of that decision. `struct stat` is not the same struct on two systems,
 * so a module carrying glibc's would be wrong on macOS with nothing at run
 * time to say so -- while this file is compiled by the C compiler *of the
 * machine being built for*, reading that machine's own header. That is the
 * whole argument: the layout question is answered where the answer is known.
 *
 * ISO C reaches none of this. A file's modification time has no answer in
 * <time.h>, which knows nothing of files, and whether a path is a directory
 * has none either; a size alone could be had from fseek and ftell, but only
 * by *opening* the file, which fails for a directory and for anything the
 * caller may not read. One call answers all three because one `stat` does.
 *
 * The three outcomes are returned rather than left to errno, so the module
 * needs no error numbers: 0 is success, 1 is nothing there, 2 is refused. The
 * distinction is drawn with `access`, which pasrt.c already names -- adding
 * ENOENT would have been a further name for no further information.
 */
int pasx_file_info(const char *path, long long *size, long long *mtime,
                   int *kind) {
  struct stat st;
  if (!path || !size || !mtime || !kind) return 2;
  if (stat(path, &st) != 0) return access(path, F_OK) == 0 ? 2 : 1;
  *size = (long long)st.st_size;
  *mtime = (long long)st.st_mtime;
  if (S_ISREG(st.st_mode)) *kind = 1;
  else if (S_ISDIR(st.st_mode)) *kind = 2;
  else *kind = 3;
  return 0;
}

/* The next entry of an open directory, for a library module that may not name
 * `struct dirent` (ADR-0185's fifth decision, ADR-0188).
 *
 * The whole content of this routine is `e->d_name`, and that is the point: the
 * offset of that member is what differs between systems. glibc puts an
 * `unsigned short` and an `unsigned char` before it, macOS a 64-bit seek offset
 * and two 16-bit fields, and POSIX itself requires only `d_ino` and `d_name` in
 * any order at all. `d_type` is not POSIX either — it is invisible under
 * `_POSIX_C_SOURCE`, which is what this file is compiled with — so what an
 * entry *is* comes from `pasx_file_info` and not from here.
 *
 * The name is returned rather than copied out, because ADR-0123's optional
 * string is a copy made at the call site: what this hands back is libc's own
 * storage, valid until the next call, and the caller has a string of its own
 * before that matters. `cap` is checked here so that an over-long name is a
 * *code* rather than the trap an over-long copy would be — which is the one
 * place a library can close doc/sop.md §7's "foreign string of unstated
 * length", since the length is known on this side.
 *
 * `readdir` answers NULL both at the end of a directory and on a failure, and
 * only errno tells them apart, so errno is cleared first. The four outcomes:
 * 0 with a name, 1 exhausted, 2 refused, 3 the name did not fit — and 3 has
 * consumed the entry, there being no way to put one back.
 */
const char *pasx_dir_next(void *d, int cap, int *status) {
  struct dirent *e;
  size_t n;
  if (!status) return NULL;
  if (!d || cap < 0) {
    *status = 2;
    return NULL;
  }
  errno = 0;
  e = readdir((DIR *)d);
  if (!e) {
    *status = errno == 0 ? 1 : 2;
    return NULL;
  }
  n = strlen(e->d_name);
  if (n > (size_t)cap) {
    *status = 3;
    return NULL;
  }
  *status = 0;
  return e->d_name;
}

/* --- sockets, for PasNet (ADR-0203) --------------------------------------
 *
 * A socket is a descriptor and a small amount of state, and neither can cross
 * the boundary: a descriptor is an integer, and AP 6.4.2.6.2 makes an integer
 * numeric on purpose, so a program could add to it, copy it and close it twice
 * (ADR-0151). So the runtime owns the object and Pascal holds an **opaque
 * pointer** -- a handle (AP 6.4.12), released by `pasx_socket_close` when the
 * variable holding it dies or is assigned `nil` (ADR-0202).
 *
 * **Nothing here names an address family, a port number or an address.** Both
 * ends are `getaddrinfo`'s: a host and a *service*, each a string, which is
 * what removes `<netinet/in.h>`, `<arpa/inet.h>`, `htons`, `sin_port` and the
 * choice between IPv4 and IPv6 from this file and from the module above it.
 * A caller writes "localhost" and "0", and what it gets back from
 * `pasx_socket_service` is a numeric string it can hand straight to a
 * connect -- so the ephemeral port a test needs is expressible without a
 * number type ever being involved.
 *
 * Two headers, and that is the whole cost: <sys/socket.h> and <netdb.h>.
 *
 * **Reading is by line and the buffer is here**, because a socket delivers
 * whatever arrived and a Pascal program wants a line. `PasStream` gets this
 * from `FILE *`; a socket cannot, since a stream opened for update over a
 * descriptor that cannot seek may not switch between reading and writing
 * without a file-positioning call. So the buffering is 40 lines of C rather
 * than a trap for whoever writes the first program that reads and writes on
 * one connection.
 *
 * **SIGPIPE is ignored**, once, where a socket is first made. Writing to a
 * connection the far end has closed raises it, and its default disposition
 * ends the process without a diagnostic -- which is not an outcome a routine
 * answering an ErrorCode can report. `signal` is ISO C; the alternatives
 * (`MSG_NOSIGNAL`, `SO_NOSIGPIPE`) are one system's each.
 */

#define PASX_SOCK_BUF 4096

struct pasx_socket {
  int fd;
  int head, tail;                 /* what has arrived and not been handed out */
  char buf[PASX_SOCK_BUF];
  char line[PASX_SOCK_BUF + 1];   /* the last line answered, NUL-terminated */
  char service[64];               /* the last service answered */
};

static struct pasx_socket *pasx_socket_new(int fd) {
  struct pasx_socket *s = malloc(sizeof *s);
  if (!s) {
    close(fd);
    return NULL;
  }
  s->fd = fd;
  s->head = 0;
  s->tail = 0;
  return s;
}

/* The handle's closer. Its result is discarded, AP 6.4.12.1 says so, and the
 * shape is `closedir`'s. */
int pasx_socket_close(void *p) {
  struct pasx_socket *s = p;
  if (!s)
    return 0;
  close(s->fd);
  free(s);
  return 0;
}

/* One end of a connection, or a listening socket, by host and service.
 *
 * `passive` chooses between them: bind-and-listen, or connect. Both walk
 * `getaddrinfo`'s list and take the first that works, which is what gives a
 * caller IPv6 without asking for it and a fallback to IPv4 without saying so.
 *
 * 0 with a socket, 1 the name or service did not resolve, 2 the system
 * refused -- there being nothing a caller can do about which of the several
 * calls in the loop failed last.
 */
static void *pasx_socket_open(const char *host, const char *service,
                              int passive, int *status) {
  struct addrinfo hints, *list, *a;
  int fd = -1, one = 1;

  if (!status)
    return NULL;
  if (!host || !service) {
    *status = 2;
    return NULL;
  }
  signal(SIGPIPE, SIG_IGN);

  memset(&hints, 0, sizeof hints);
  hints.ai_family = AF_UNSPEC;
  hints.ai_socktype = SOCK_STREAM;
  if (passive)
    hints.ai_flags = AI_PASSIVE;
  if (getaddrinfo(host, service, &hints, &list) != 0) {
    *status = 1;
    return NULL;
  }

  for (a = list; a; a = a->ai_next) {
    fd = socket(a->ai_family, a->ai_socktype, a->ai_protocol);
    if (fd < 0)
      continue;
    if (passive) {
      setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &one, sizeof one);
      if (bind(fd, a->ai_addr, a->ai_addrlen) == 0 && listen(fd, 16) == 0)
        break;
    } else if (connect(fd, a->ai_addr, a->ai_addrlen) == 0) {
      break;
    }
    close(fd);
    fd = -1;
  }
  freeaddrinfo(list);

  if (fd < 0) {
    *status = 2;
    return NULL;
  }
  *status = 0;
  return pasx_socket_new(fd);
}

void *pasx_socket_connect(const char *host, const char *service, int *status) {
  return pasx_socket_open(host, service, 0, status);
}

void *pasx_socket_listen(const char *host, const char *service, int *status) {
  return pasx_socket_open(host, service, 1, status);
}

/* The next connection to a listening socket, as a socket of its own. */
void *pasx_socket_accept(void *p, int *status) {
  struct pasx_socket *s = p;
  int fd;
  if (!status)
    return NULL;
  if (!s) {
    *status = 2;
    return NULL;
  }
  fd = accept(s->fd, NULL, NULL);
  if (fd < 0) {
    *status = 2;
    return NULL;
  }
  *status = 0;
  return pasx_socket_new(fd);
}

/* The service this socket is bound to, as the numeric string `getaddrinfo`
 * would take back. It is how a caller that asked for service "0" learns which
 * ephemeral port it was given. */
const char *pasx_socket_service(void *p, int cap, int *status) {
  struct pasx_socket *s = p;
  struct sockaddr_storage addr;
  socklen_t len = sizeof addr;
  if (!status)
    return NULL;
  if (!s || cap < 0) {
    *status = 2;
    return NULL;
  }
  if (getsockname(s->fd, (struct sockaddr *)&addr, &len) != 0) {
    *status = 2;
    return NULL;
  }
  if (getnameinfo((struct sockaddr *)&addr, len, NULL, 0, s->service,
                  sizeof s->service, NI_NUMERICHOST | NI_NUMERICSERV) != 0) {
    *status = 2;
    return NULL;
  }
  if (strlen(s->service) > (size_t)cap) {
    *status = 3;
    return NULL;
  }
  *status = 0;
  return s->service;
}

/* Every byte of `data`, looping over a partial write. 0, or 2 on a refusal. */
int pasx_socket_write(void *p, const char *data) {
  struct pasx_socket *s = p;
  size_t left;
  if (!s || !data)
    return 2;
  left = strlen(data);
  while (left > 0) {
    ssize_t n = write(s->fd, data, left);
    if (n <= 0) {
      if (n < 0 && errno == EINTR)
        continue;
      return 2;
    }
    data += n;
    left -= (size_t)n;
  }
  return 0;
}

/* The next line, without its terminator, from the buffer above -- refilling it
 * when there is no newline in what is held.
 *
 * 0 with a line, 1 the far end closed and nothing was left, 2 a refusal, 3 the
 * line did not fit `cap`. A final line with no newline is a line: a socket has
 * no obligation to end with one, and discarding it would lose data the far end
 * sent.
 */
const char *pasx_socket_readline(void *p, int cap, int *status) {
  struct pasx_socket *s = p;
  int i, n;

  if (!status)
    return NULL;
  if (!s || cap < 0) {
    *status = 2;
    return NULL;
  }
  for (;;) {
    for (i = s->head; i < s->tail; i++) {
      if (s->buf[i] == '\n') {
        int len = i - s->head;
        if (len > 0 && s->buf[i - 1] == '\r')
          len--;
        if (len > cap) {
          *status = 3;
          s->head = i + 1;
          return NULL;
        }
        memcpy(s->line, s->buf + s->head, (size_t)len);
        s->line[len] = '\0';
        s->head = i + 1;
        *status = 0;
        return s->line;
      }
    }
    if (s->head > 0) {          /* make room, keeping the partial line */
      memmove(s->buf, s->buf + s->head, (size_t)(s->tail - s->head));
      s->tail -= s->head;
      s->head = 0;
    }
    if (s->tail == PASX_SOCK_BUF) {
      *status = 3;              /* longer than anything this can buffer */
      s->tail = 0;
      return NULL;
    }
    n = (int)read(s->fd, s->buf + s->tail, (size_t)(PASX_SOCK_BUF - s->tail));
    if (n < 0) {
      if (errno == EINTR)
        continue;
      *status = 2;
      return NULL;
    }
    if (n == 0) {               /* the far end closed */
      int len = s->tail - s->head;
      if (len <= 0) {
        *status = 1;
        return NULL;
      }
      if (len > cap) {
        *status = 3;
        s->head = s->tail;
        return NULL;
      }
      memcpy(s->line, s->buf + s->head, (size_t)len);
      s->line[len] = '\0';
      s->head = s->tail;
      *status = 0;
      return s->line;
    }
    s->tail += n;
  }
}
