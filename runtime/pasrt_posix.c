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
#include <fcntl.h>
#include <netdb.h>
#include <poll.h>
#include <signal.h>
#include <spawn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <termios.h>
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

/* Does a line already sit in the buffer above, so that
 * `pasx_socket_readline` would answer without a `read`?
 *
 * This is the half of readiness `poll` cannot see, and it is not an
 * optimisation: those bytes have already been taken off the socket, so the
 * descriptor is *not* readable and a program waiting on it alone would sit
 * there holding a line it had been handed. A full buffer with no newline
 * counts too -- readline answers "too long" out of it without reading.
 */
static int pasx_socket_buffered(const struct pasx_socket *s) {
  int i;
  for (i = s->head; i < s->tail; i++)
    if (s->buf[i] == '\n')
      return 1;
  return s->head == 0 && s->tail == PASX_SOCK_BUF;
}

int pasx_socket_pending(void *p) {
  struct pasx_socket *s = p;
  return s && pasx_socket_buffered(s);
}

/* The descriptor, for the caller to put in an array `pasx_socket_poll` reads.
 *
 * It is the one place a descriptor leaves this file, and PasNet keeps it to
 * itself: what ADR-0203 refuses is a *program* holding one, a descriptor
 * being an integer and an integer being numeric.
 */
int pasx_socket_fd(void *p) {
  struct pasx_socket *s = p;
  return s ? s->fd : -1;
}

/* Which of `fds` can be read from, or accepted from, without blocking.
 *
 * `nfds` descriptors in and `ngot` flags out, both counts coming from the
 * slices the caller passed (ADR-0129) and required to agree -- which is the
 * whole of the argument checking here, a slice's count being one the program
 * cannot write. A **negative** descriptor is a slot nobody is watching:
 * POSIX has `poll` ignore it and set its `revents` to zero, so a caller with
 * holes in its list needs no compaction and this needs no skip list.
 *
 * `timeout_ms` is `poll`'s own: negative waits indefinitely, zero asks and
 * returns.
 *
 * Answers how many are ready, or -1 on a refusal. `EINTR` is retried with
 * the timeout unadjusted, which can make a signal-heavy program wait longer
 * than it asked for; the alternative is a clock, and naming one here would
 * cost a header for a case no program in this tree has.
 */
/* Is there something to read on this descriptor, within `timeout_ms`?
 * 1 yes, 0 the timeout expired, -1 refused. `timeout_ms` is poll's own: a
 * negative one waits indefinitely and zero asks and returns (ADR-0257).
 *
 * `pasx_socket_poll` above answers the same question for a *list*, and is
 * not what a caller with one descriptor wants: its contract is a pair of
 * slices whose lengths must agree, which is right for a server holding many
 * sockets and an awkward way to ask about standard input.
 *
 * **What it does not answer.** POSIX makes a regular file always ready, so a
 * program reading a redirected standard input is told "yes" at end of file
 * and forever after. That is not a defect here and cannot be fixed here --
 * readiness is a property of the descriptor and a regular file genuinely has
 * no waiting -- but a caller using this to decide whether a *message* has
 * arrived has to say what a message is and read one, which is exactly what
 * `PasLsp.LspPending` does. It is a permission to try a read and never a
 * promise that one will yield anything.
 */
int pasx_fd_ready(int fd, int timeout_ms) {
  struct pollfd pf;
  int n;

  if (fd < 0)
    return -1;
  pf.fd = fd;
  pf.events = POLLIN;
  pf.revents = 0;
  for (;;) {
    n = poll(&pf, (nfds_t)1, timeout_ms);
    if (n >= 0 || errno != EINTR)
      break;
  }
  if (n < 0)
    return -1;
  return n > 0 && pf.revents != 0;
}

int pasx_socket_poll(const int *fds, long long nfds, int *got, long long ngot,
                     int timeout_ms) {
  struct pollfd *pf;
  long long i;
  int n;

  if (!fds || !got || nfds < 0 || ngot != nfds)
    return -1;
  for (i = 0; i < ngot; i++)
    got[i] = 0;
  if (nfds == 0)
    return 0;
  pf = malloc((size_t)nfds * sizeof *pf);
  if (!pf)
    return -1;
  for (i = 0; i < nfds; i++) {
    pf[i].fd = fds[i];
    pf[i].events = POLLIN;
    pf[i].revents = 0;
  }
  for (;;) {
    n = poll(pf, (nfds_t)nfds, timeout_ms);
    if (n >= 0 || errno != EINTR)
      break;
  }
  if (n < 0) {
    free(pf);
    return -1;
  }
  n = 0;
  for (i = 0; i < nfds; i++)
    if (pf[i].fd >= 0 && pf[i].revents != 0) {
      got[i] = 1;
      n++;
    }
  free(pf);
  return n;
}

/* --- the terminal, for PasTerm --------------------------------------------
 *
 * `struct termios` and `struct winsize` are two more layouts a library module
 * may not declare (ADR-0185's fifth decision), and they are worse subjects
 * than `struct stat`: `termios` is five fields and an array whose length is
 * `NCCS`, which is 32 on Linux and 20 on macOS, and the *bit* each flag names
 * differs between systems as well as the offset. A module carrying either
 * would be one platform's header written out as a constant. So the whole of
 * the terminal is behind `pasx_term_*` and nothing above this line names a
 * flag.
 *
 * Two headers. <termios.h> is POSIX and answers everything but one question;
 * <sys/ioctl.h> answers that one -- **POSIX has no window size at all**, and
 * `TIOCGWINSZ` with `struct winsize` is the BSD-derived request every Unix
 * has instead. It is named here rather than argued away because the
 * alternative is the `COLUMNS` environment variable, which is a shell's
 * opinion recorded before the window was last resized.
 *
 * **The saved state is the runtime's, and there is one.** A caller cannot
 * hold it -- that is the whole reason this section exists -- so `pasx_term_raw`
 * keeps the terminal's original settings here and `pasx_term_restore` puts
 * them back. One slot and not a table: a second `pasx_term_raw` while one is
 * outstanding would save the *raw* settings as though they were the original,
 * and the restore after it would leave the user's terminal in raw mode with
 * no echo and no interrupt character -- a broken shell and no diagnostic. So
 * it is refused (3) rather than counted, and a program driving two terminals
 * at once is a program this does not serve.
 *
 * **And it is put back at exit**, by an `atexit` handler registered the first
 * time raw mode is entered -- `--coverage`'s discipline, so a program that
 * never asks pays nothing. That is not tidiness: raw mode is a property of
 * the *terminal* and not of the process, so a program that stops without
 * restoring hands the user a shell that does not echo, and the user's only
 * remedy is to type `stty sane` blind. `halt`, a runtime error and a return
 * from the main program block all reach `exit` and so all reach this;
 * `_exit`, `abort` and a fatal signal do not, and nothing portable can make
 * them -- a signal handler that touched this state would have to be
 * async-signal-safe and would still miss SIGKILL.
 *
 * **What raw mode is** is written out below rather than taken from
 * `cfmakeraw`, which is not POSIX and is invisible under the
 * `_POSIX_C_SOURCE` this file is compiled with. Every flag cleared is named,
 * which is also the documentation: no echo, no line discipline, no signal
 * characters, no flow control, no output post-processing, and a read that
 * waits for one byte and no longer.
 */

static struct termios pasx_term_saved;
static int pasx_term_saved_fd = -1;
static int pasx_term_atexit_done = 0;

/* Is this descriptor a terminal? 1 or 0, and never an error: `isatty` fails
 * exactly when the answer is no. */
int pasx_term_isatty(int fd) {
  return fd >= 0 && isatty(fd) ? 1 : 0;
}

/* The window, in character cells. 0 with both, 1 where the descriptor is not
 * a terminal or is one that does not know its own size, 2 where the system
 * refused.
 *
 * The size is asked of a *descriptor* and not of the process, because the two
 * can differ: a program whose output is a pipe and whose error stream is
 * still the terminal has a window size, and only one of its descriptors can
 * report it.
 */
int pasx_term_size(int fd, int *rows, int *cols) {
  struct winsize ws;

  if (!rows || !cols)
    return 2;
  *rows = 0;
  *cols = 0;
  if (fd < 0)
    return 2;
  if (!isatty(fd))
    return 1;
  if (ioctl(fd, TIOCGWINSZ, &ws) != 0)
    return 2;
  /* A pseudo-terminal nobody has sized answers zero for both, which is a
     window size in the same sense an empty answer is a name: not one. */
  if (ws.ws_row == 0 || ws.ws_col == 0)
    return 1;
  *rows = (int)ws.ws_row;
  *cols = (int)ws.ws_col;
  return 0;
}

/* The saved settings, put back. Registered with `atexit` and called by
 * `pasx_term_restore`; both leave the slot empty, so putting them back twice
 * is not putting the raw ones back once. */
static void pasx_term_at_exit(void) {
  int fd = pasx_term_saved_fd;
  if (fd >= 0) {
    pasx_term_saved_fd = -1;
    tcsetattr(fd, TCSAFLUSH, &pasx_term_saved);
  }
}

/* Enter raw mode on `fd`, remembering what it was.
 *
 * 0 done, 1 not a terminal, 2 refused, 3 raw mode is already entered and
 * nothing has been changed.
 *
 * `TCSAFLUSH` on the way in discards whatever the user typed while the
 * program was still line-buffered, which is what stops a stray newline being
 * delivered as the first "key".
 */
int pasx_term_raw(int fd) {
  struct termios raw;

  if (fd < 0)
    return 2;
  if (pasx_term_saved_fd >= 0)
    return 3;
  if (!isatty(fd))
    return 1;
  if (tcgetattr(fd, &pasx_term_saved) != 0)
    return 2;

  raw = pasx_term_saved;
  /* No echo, no line assembly, no INTR/QUIT/SUSP, no ^V literal-next. */
  raw.c_lflag &= (tcflag_t) ~(ECHO | ICANON | ISIG | IEXTEN);
  /* No ^S/^Q, no CR-to-NL, no break-as-interrupt, no parity meddling. */
  raw.c_iflag &= (tcflag_t) ~(BRKINT | ICRNL | INPCK | ISTRIP | IXON);
  /* Nothing added to what the program writes -- a bare newline stays one. */
  raw.c_oflag &= (tcflag_t) ~OPOST;
  raw.c_cflag |= (tcflag_t)CS8;
  /* A read waits for one byte and then answers; a key is not a line. */
  raw.c_cc[VMIN] = 1;
  raw.c_cc[VTIME] = 0;
  if (tcsetattr(fd, TCSAFLUSH, &raw) != 0)
    return 2;

  pasx_term_saved_fd = fd;
  if (!pasx_term_atexit_done && atexit(pasx_term_at_exit) == 0)
    pasx_term_atexit_done = 1;
  return 0;
}

/* Leave raw mode, on whichever descriptor entered it.
 *
 * It takes no descriptor on purpose: the runtime knows which one it saved,
 * and a caller passing the wrong one would be asking to write one terminal's
 * settings onto another. 0 restored, 1 nothing was saved, 2 refused.
 */
int pasx_term_restore(void) {
  int fd = pasx_term_saved_fd;

  if (fd < 0)
    return 1;
  pasx_term_saved_fd = -1;
  return tcsetattr(fd, TCSAFLUSH, &pasx_term_saved) == 0 ? 0 : 2;
}

/* Is raw mode entered? The one question a caller cannot answer for itself,
 * the state being here. */
int pasx_term_raw_active(void) {
  return pasx_term_saved_fd >= 0 ? 1 : 0;
}

/* --- an argument vector, and the process it starts (ADR-0362) -------------
 *
 * `PasProcess.Run` and `Capture` hand a *string* to `system` and `popen`, and
 * the shell then decides where one word ends and the next begins. That is the
 * right interface for a command a program wrote out and the wrong one for a
 * command assembled out of values -- a path, a flag, something a caller sent
 * -- because every such value is read as shell syntax. `lsp/pasls.pas` quoted
 * its path with apostrophes and a path containing one escaped the quoting;
 * ADR-0362 has the probe.
 *
 * So this is the other interface: the words are carried as words and no shell
 * ever sees them. The vector is built here rather than in Pascal because argv
 * is a `char *[]` -- an array of pointers, which AP 6.7.7.6.2's boundary has
 * no way to spell -- so the caller pushes one string at a time and the
 * pointers never cross. It is a handle (AP 6.4.12): `pasx_argv_free` is its
 * closer, so the words are freed when the Pascal variable dies.
 *
 * **`posix_spawn` and not `fork`.** This language has two threads of control
 * (AP 6.9.3.12), and a `fork` in a process with more than one leaves the child
 * able to call only what is async-signal-safe -- `execvp` searching a PATH is
 * not on that list on every libc. `posix_spawn` exists for exactly this and
 * the implementation does whatever its system makes safe.
 *
 * `posix_spawnp` is the PATH-searching form, which is what a driver needs:
 * `echo` rather than `/bin/echo`. POSIX lets a system report a command that
 * cannot be executed either from the call or through a child that exits 127,
 * and the two are told apart nowhere; doc/implementation-defined.md records
 * which this one does.
 */

/* The most words this will carry. It is a bound and not a budget: a command
 * line long enough to reach it is one the operating system would refuse for
 * ARG_MAX anyway, and a caller that reaches it is told rather than growing
 * until malloc fails. */
#define PASX_ARGV_MAX 4096

/* The child inherits this process's environment, and `environ` is how a
 * spawn is told so. POSIX declares it in <unistd.h>, and glibc puts that
 * declaration behind a feature-test macro this file does not set -- so it is
 * written out here, which is what POSIX itself tells a program to do. */
extern char **environ;

struct pasx_argv {
  char **v; /* NULL-terminated, which is what argv is */
  int n;    /* words pushed */
  int cap;  /* slots, always at least n + 1 so v[n] is the NULL */
};

/* An empty vector, or NULL where there was no memory. */
void *pasx_argv_new(void) {
  struct pasx_argv *a = malloc(sizeof *a);

  if (!a)
    return NULL;
  a->n = 0;
  a->cap = 8;
  a->v = malloc((size_t)a->cap * sizeof *a->v);
  if (!a->v) {
    free(a);
    return NULL;
  }
  a->v[0] = NULL;
  return a;
}

/* Copy one word onto the end. 0 written, 1 no room, 2 nothing to write to.
 *
 * The copy is this vector's own: the caller's string is a Pascal value whose
 * lifetime is its block, and the words have to outlive the push. */
int pasx_argv_push(void *p, const char *s) {
  struct pasx_argv *a = p;
  size_t n;
  char *copy;

  if (!a || !s)
    return 2;
  if (a->n >= PASX_ARGV_MAX)
    return 1;
  if (a->n + 2 > a->cap) {
    int cap = a->cap * 2;
    char **v = realloc(a->v, (size_t)cap * sizeof *v);

    if (!v)
      return 1;
    a->v = v;
    a->cap = cap;
  }
  n = strlen(s);
  copy = malloc(n + 1);
  if (!copy)
    return 1;
  memcpy(copy, s, n + 1);
  a->v[a->n++] = copy;
  a->v[a->n] = NULL;
  return 0;
}

/* How many words are in it, so that a caller can refuse to run an empty one
 * without keeping a count of its own. */
int pasx_argv_count(void *p) {
  struct pasx_argv *a = p;

  return a ? a->n : 0;
}

/* Drop every word after the first `keep` of them, so that a caller which
 * speculated -- pushed the words of a candidate and then found it was the
 * wrong one -- can put the vector back where it was. `ArgsLen` before is the
 * mark; this is the reset. Answers how many are left. */
int pasx_argv_drop(void *p, int keep) {
  struct pasx_argv *a = p;

  if (!a)
    return 0;
  if (keep < 0)
    keep = 0;
  while (a->n > keep)
    free(a->v[--a->n]);
  a->v[a->n] = NULL;
  return a->n;
}

/* The closer. Answers 0 always: there is nothing a release can be told. */
int pasx_argv_free(void *p) {
  struct pasx_argv *a = p;
  int i;

  if (!a)
    return 0;
  for (i = 0; i < a->n; i++)
    free(a->v[i]);
  free(a->v);
  free(a);
  return 0;
}

/* A running child, and the stream its output arrives on when one was asked
 * for. It is a handle for the reason the vector is: what a program would hold
 * otherwise is a process identifier, which AP 6.4.2.6.2 would let it add to
 * and wait for twice (ADR-0151). */
struct pasx_proc {
  pid_t pid;
  FILE *out; /* NULL when nothing was captured */
};

/* Start `argvp`. `capture` says where the child's output goes: 0 leaves both
 * streams this process's, 1 puts its standard output on a pipe, 2 puts its
 * output and its standard error together on one -- which is what `2>&1` used
 * to be written for and cannot be written at all where no shell reads it --
 * and 3 sends both to the file `path` names, created or truncated.
 *
 * Mode 3 is here rather than left to the caller because a dump can be larger
 * than any string a program would size for it: the caller that needs it is
 * asking the compiler for a table and reading the file afterwards.
 *
 * status: 0 started, 1 no words to run, 2 the system refused.
 */
void *pasx_exec_start(void *argvp, int capture, const char *path, int *status) {
  struct pasx_argv *a = argvp;
  struct pasx_proc *pr;
  posix_spawn_file_actions_t fa;
  int fds[2], rc;
  pid_t pid;

  if (!status)
    return NULL;
  if (!a || a->n == 0) {
    *status = 1;
    return NULL;
  }
  pr = malloc(sizeof *pr);
  if (!pr) {
    *status = 2;
    return NULL;
  }
  pr->out = NULL;
  fds[0] = -1;
  fds[1] = -1;
  if ((capture == 1 || capture == 2) && pipe(fds) != 0) {
    free(pr);
    *status = 2;
    return NULL;
  }
  if (posix_spawn_file_actions_init(&fa) != 0) {
    if (fds[0] >= 0) {
      close(fds[0]);
      close(fds[1]);
    }
    free(pr);
    *status = 2;
    return NULL;
  }
  if (capture == 1 || capture == 2) {
    /* The read end has no business in the child, and the write end is a
     * descriptor it should not see under its own number either: a child that
     * kept it open would hold the pipe open after it exited and the reader
     * would never see the end of the stream. */
    posix_spawn_file_actions_adddup2(&fa, fds[1], 1);
    if (capture == 2)
      posix_spawn_file_actions_adddup2(&fa, fds[1], 2);
    posix_spawn_file_actions_addclose(&fa, fds[0]);
    posix_spawn_file_actions_addclose(&fa, fds[1]);
  } else if (capture == 3) {
    if (!path || !*path) {
      posix_spawn_file_actions_destroy(&fa);
      free(pr);
      *status = 2;
      return NULL;
    }
    /* The child opens it, so a file this process may not create is the
     * child's failure to start and not a half-run command. */
    posix_spawn_file_actions_addopen(&fa, 1, path,
                                     O_WRONLY | O_CREAT | O_TRUNC, 0666);
    posix_spawn_file_actions_adddup2(&fa, 1, 2);
  }
  rc = posix_spawnp(&pid, a->v[0], &fa, NULL, a->v, environ);
  posix_spawn_file_actions_destroy(&fa);
  if (rc != 0) {
    if (fds[0] >= 0) {
      close(fds[0]);
      close(fds[1]);
    }
    free(pr);
    *status = 2;
    return NULL;
  }
  if (fds[0] >= 0) {
    close(fds[1]);
    pr->out = fdopen(fds[0], "r");
    if (!pr->out)
      close(fds[0]);
  }
  pr->pid = pid;
  *status = 0;
  return pr;
}

/* The next character of what the child wrote, or -1 at the end of it and
 * whenever nothing was captured. A character at a time is PasStream's shape
 * and `Collect`'s; the stream is buffered, so it is not a system call each. */
int pasx_exec_getc(void *p) {
  struct pasx_proc *pr = p;

  if (!pr || !pr->out)
    return -1;
  return fgetc(pr->out);
}

/* Wait for the child and release it: the closer, so a Pascal variable holding
 * one is waited for at the end of its block whatever else happened.
 *
 * Answers the exit code, or -1 where the child did not exit normally -- it was
 * killed by a signal, or could not be waited for at all. A signal is not given
 * a number of its own here for the reason `ExitCode` gives: the caller has
 * `RunResult`, whose failure side is a reason and not a status. */
int pasx_exec_close(void *p) {
  struct pasx_proc *pr = p;
  int st = 0, code;

  if (!pr)
    return -1;
  if (pr->out)
    fclose(pr->out);
  /* EINTR is the one failure worth retrying: a signal arriving while this
   * process waits says nothing about the child. */
  while (waitpid(pr->pid, &st, 0) < 0) {
    if (errno != EINTR) {
      free(pr);
      return -1;
    }
  }
  code = WIFEXITED(st) ? WEXITSTATUS(st) : -1;
  free(pr);
  return code;
}
