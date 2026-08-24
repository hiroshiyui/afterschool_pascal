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
#include <string.h>
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
