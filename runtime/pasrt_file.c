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

/* The file model, and the whole of what it needs from POSIX.
 *
 * `runtime/pasrt_posix.c` was one unit and held two different kinds of thing
 * (ADR-0405): the questions an operating system answers *about a file* -- how
 * big is it, what is in this directory, is there anything to read yet, give me
 * a directory of my own -- and the things it does **besides** files: start a
 * process, open a socket, put a terminal into raw mode. Those are one unit's
 * worth of POSIX and two units' worth of *portability*, because a target may
 * have a file system and no processes at all, and wasm32-wasi is exactly that
 * target.
 *
 * **The line is drawn by a rule and not by a target's list**, and the rule is
 * *a question and not an action*: what is here asks the operating system
 * about a file or a descriptor that already exists -- how big is it, what is
 * in this directory, is there anything to read yet -- and answers. Everything
 * that makes the machine *do* something is next door, which is why
 * `pasx_temp_dir` stayed there: making a private directory is an act, and
 * `mkdtemp` is the POSIX primitive that performs it. Asking about a file is
 * the part of an operating system a target is least likely to be without,
 * which is why that rule and portability point the same way -- but the rule
 * came first and is what a routine is placed by.
 *
 * The rules of `pasrt_posix.c` are this file's too, and unchanged:
 *
 *   - Nothing the *compiler* emits calls into here. Everything is `pasx_`,
 *     which is the prefix a Pascal program may bind by name (ADR-0131), so a
 *     system without these calls loses library routines and not the language.
 *   - Every non-ISO header it includes is named in
 *     tests/checks/nonstandard_c.txt, and `runtime-isoc` fails in both
 *     directions over that list.
 *   - It stays small. What belongs here is what a *library module* cannot ask
 *     C for itself, which is a struct whose layout differs between systems
 *     (ADR-0185); everything a program can declare and check, it should.
 *
 * **A header being present is not the target having the thing**, which is how
 * the terminal came to stay next door: wasi-libc ships `<sys/ioctl.h>` and has
 * no `struct winsize` and no `TIOCGWINSZ`, so `pasx_term_size` does not
 * compile for it however the units are cut. `pasx_term_isatty` would have,
 * and follows the rest of the terminal rather than being separated from it for
 * one target's convenience.
 */

#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

#include "pasrt_file.h"

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
