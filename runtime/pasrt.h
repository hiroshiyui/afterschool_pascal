/* Afterschool Pascal runtime library.
 * Copyright (C) 2026 Hui-Hong You
 *
 * This library is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option)
 * any later version.
 *
 * This library is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
 * or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
 * for more details.
 *
 * As a special exception, if you link this library with other files to
 * produce an executable, that does not by itself cause the resulting
 * executable to be covered by the GNU General Public License.  This exception
 * does not however invalidate any other reasons why the executable file might
 * be covered by the GNU General Public License.  See COPYING.RUNTIME.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

/* The part of the runtime's interface the code generator has to agree with.
 *
 * A file variable's storage is opaque to the compiler: it alloca's this many
 * bytes in the activation record and passes their address to the pas_* calls
 * below. Keeping `struct pas_file` private to the runtime is what lets it
 * change without changing codegen.cpp — but the *size* cannot be private, so
 * it lives here rather than being written out in both places.
 *
 * What the compiler does have to tell the runtime is the *component* type:
 * `pas_file_init` takes its size in bytes and whether the file is a `text`.
 * Those two are the whole of the difference between a text file and a
 * `file of T` — see ADR-0031. */
#ifndef APASCAL_PASRT_H
#define APASCAL_PASRT_H

#define PAS_FILE_SIZE 120

/* The storage a block needs to be the target of a non-local `goto`: somewhere
 * to jump back to, and the mark that says which files the jump abandons. It is
 * opaque for the same reason a file variable is, and sized here for the same
 * reason — `jmp_buf` is the platform's business and the compiler must not have
 * an opinion about it. See ADR-0032.
 *
 * **A per-target maximum, not a measurement of this one** (ADR-0155). It was
 * 256, which is what `struct pas_jump` needs on x86-64 and nowhere else, so the
 * _Static_assert below stopped an aarch64 build before anything else could.
 * Measured with the cross toolchains this repository's CI has:
 *
 *     x86-64   jmp_buf 200   struct pas_jump 216
 *     aarch64  jmp_buf 312   struct pas_jump 328
 *     armhf    jmp_buf 392   struct pas_jump 400   <- 32-bit, and the largest
 *     i686     jmp_buf 156   struct pas_jump 164
 *
 * glibc's powerpc64 is the largest one not measurable here: __jmp_buf is 64
 * longs, so the struct is about 648. 1024 clears every one of them with room,
 * and the cost is paid only by a block that is the target of a non-local goto,
 * which is the only kind that carries a record at all.
 *
 * It must equal `jumpSize` in selfhost/compiler.pas, which is what actually
 * allocates the bytes; selfhost/irtest.sh checks the two, and
 * tests/checks/target_sizes.sh checks that the number is enough for every
 * target a cross compiler is installed for. */
#define PAS_JUMP_SIZE 1024

/* How reset/rewrite find the external file a file variable stands for.
 * ISO 7185 §6.10 makes the binding implementation-defined; this compiler binds
 * the program parameters after `input` and `output` to command-line arguments,
 * in the order they are written. */
enum {
  PAS_BIND_INTERNAL = 0, /* not a program parameter: a scratch file */
  PAS_BIND_INPUT = 1,    /* the standard input */
  PAS_BIND_OUTPUT = 2,   /* the standard output */
  PAS_BIND_ARG = 3       /* argv[n], n counted over the file parameters */
};

#endif
