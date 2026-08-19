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

/* Afterschool Pascal runtime library.
 *
 * Everything the generated code cannot express directly in LLVM IR lives here:
 * text files, formatted output, and the handful of runtime checks the compiler
 * emits.
 *
 * Field-width conventions (see README):
 *   width < 0  means "no width given"
 *   prec  < 0  means "no precision given"
 */
#include <errno.h>
#include <math.h>
#include <setjmp.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#include "pasrt.h"

void pas_runtime_error(const char *msg) {
  fflush(stdout);
  fprintf(stderr, "runtime error: %s\n", msg);
  exit(1);
}

/* --- statement coverage, for `pascalc --coverage` (ADR-0104) --------------
 *
 * The compiler emits one call to pas_cov_hit per statement, carrying the line
 * the statement begins on. Nothing here decides what is executable: the
 * *denominator* is the set of lines the compiler emitted a call for, which is
 * readable from the IR it wrote, so the two halves of a coverage figure come
 * from the same artefact and cannot disagree about what was instrumented.
 *
 * A program not compiled with --coverage calls none of this, and the table is
 * allocated on the first call, so an ordinary program pays a symbol in
 * libpasrt.a and nothing else -- no BSS, no atexit, no startup cost. */
static unsigned char *pas_cov_seen;
static int pas_cov_cap;
static int pas_cov_high;
static int pas_cov_armed;

/* Written at exit rather than per hit, because a compiler run makes millions of
 * hits and one line's first is the only one that matters. Appended, so a corpus
 * of runs accumulates into one file the way SanitizerCoverage's does. */
static void pas_cov_dump(void) {
  const char *path = getenv("PASCOV_LINES");
  FILE *f;
  int i;

  if (!path || !pas_cov_seen) return;
  f = fopen(path, "a");
  if (!f) return;
  for (i = 0; i <= pas_cov_high; i++)
    if (pas_cov_seen[i]) fprintf(f, "%d\n", i);
  fclose(f);
}

/* Line numbers arrive in no particular order and the highest is not known in
 * advance, so the table grows. Doubling from the largest line seen keeps this
 * O(1) amortised over a run that calls it millions of times. */
void pas_cov_hit(int line) {
  if (line < 0) return;
  if (line >= pas_cov_cap) {
    int want = pas_cov_cap ? pas_cov_cap : 1024;
    unsigned char *grown;
    while (want <= line) want *= 2;
    grown = realloc(pas_cov_seen, (size_t)want);
    if (!grown) return; /* measurement must never break the program */
    memset(grown + pas_cov_cap, 0, (size_t)(want - pas_cov_cap));
    pas_cov_seen = grown;
    pas_cov_cap = want;
    /* Its own flag rather than "is the table empty": the table grows more than
     * once, and line 0 is a legal hit, so neither the capacity nor the highest
     * line seen can answer whether this has already been done. */
    if (!pas_cov_armed) {
      pas_cov_armed = 1;
      atexit(pas_cov_dump);
    }
  }
  pas_cov_seen[line] = 1;
  if (line > pas_cov_high) pas_cov_high = line;
}

/// The same message the compiler writes for an array whose bounds it knows,
/// for one whose bounds arrive with the actual (ISO/IEC 10206:1991 §6.7.3.3).
/// A schematic formal parameter is compiled once for every tuple, so the text
/// cannot be a constant in the generated program and is built here instead.
void pas_index_error(int lo, int hi) {
  fflush(stdout);
  fprintf(stderr, "runtime error: array index out of bounds (%d..%d)\n", lo,
          hi);
  exit(1);
}

/// ISO/IEC 10206:1991 §6.4.6 d): two types produced from one schema with
/// different tuples are different types, and an assignment between them is a
/// dynamic-violation. The schema and the discriminant are named where the
/// program was compiled and the values are known only where it runs, so the
/// two halves of the message meet here.
void pas_disc_error(const char *schema, const char *disc, int left,
                    int right) {
  fflush(stdout);
  fprintf(stderr,
          "runtime error: assignment needs one type: schema '%s' with %s = %d "
          "and %s = %d\n",
          schema, disc, left, disc, right);
  exit(1);
}

/// ISO 7185 §6.7.2.5 compares two strings character by character and gives the
/// operators only to strings of one length. Where both lengths are written in
/// the program the compiler says so; where one is a discriminant, this does.
void pas_length_error(int left, int right) {
  fflush(stdout);
  fprintf(stderr,
          "runtime error: strings of different lengths cannot be compared "
          "(%d and %d)\n",
          left, right);
  exit(1);
}

static void pas_error2(const char *msg, const char *what) {
  fflush(stdout);
  fprintf(stderr, "runtime error: %s%s\n", msg, what);
  exit(1);
}

/* ---------------------------------------------------------- exponentiation */

/* ISO/IEC 10206:1991 §6.8.3.2's two exponentiating operators. They are the one
 * arithmetic operation with no instruction behind it, so the error conditions
 * the clause states live here rather than being emitted around a call:
 *
 *   x ** y and x pow y are an error if x is zero and y <= 0
 *   x ** y is an error if x is negative
 *
 * The integer type is -maxint..maxint (ISO 7185 §6.4.2.2), so `pow` traps on
 * overflow exactly as `*` does — it *is* repeated multiplication, and a
 * silently wrapped power would be the one arithmetic operator that wraps. */

#define PAS_MAXINT 2147483647

double pas_pow_real(double x, double y) {
  if (x == 0.0 && y <= 0.0)
    pas_runtime_error("**: 0 ** y is an error when y <= 0");
  /* The clause admits no negative left operand: the value is defined as an
   * approximation to exp(y*ln(x)), and ln of a negative number is nothing. A
   * negative base is what `pow` is for, where the exponent is an integer. */
  if (x < 0.0)
    pas_runtime_error("**: a negative left operand needs an integer exponent; "
                      "use pow");
  if (x == 0.0)
    return 0.0;
  if (y == 0.0)
    return 1.0;
  return pow(x, y);
}

double pas_pow_realint(double x, int y) {
  if (x == 0.0 && y <= 0)
    pas_runtime_error("pow: 0 pow y is an error when y <= 0");
  if (x == 0.0)
    return 0.0;
  if (y == 0)
    return 1.0;
  /* Defined as an approximation to repeated multiplication, and pow() is one —
   * an exact one for an integral exponent, which repeated multiplication is
   * not. A negative base is fine here, unlike under `**`. */
  return pow(x, (double)y);
}

int pas_pow_int(int x, int y) {
  long long acc = 1;
  int i;
  if (x == 0 && y <= 0)
    pas_runtime_error("pow: 0 pow y is an error when y <= 0");
  if (x == 0)
    return 0;
  if (y == 0)
    return 1;
  if (y < 0) {
    /* §6.8.3.2 spells the negative case out as (1 div x) pow (-y), and that is
     * integer division: every base but 1 and -1 gives zero, and zero to a
     * positive power is zero. Negating y is safe because -maxint..maxint is
     * symmetric — INT_MIN is not a value of the type. */
    x = 1 / x;
    y = -y;
    if (x == 0)
      return 0;
  }
  for (i = 0; i < y; i++) {
    acc *= x;
    if (acc > PAS_MAXINT || acc < -PAS_MAXINT)
      pas_runtime_error("integer overflow in pow");
  }
  return (int)acc;
}

/* Three libm functions the emitter needs, under names of this runtime's own.
 *
 * They are here for a reason that has nothing to do with arithmetic. ADR-0121
 * lets a program name a linker symbol -- `external 'hypot'` -- and LLVM's
 * assembler refuses a second declaration of any global however identical the
 * two are, so a name the emitted module *already* declares is one a program
 * cannot have. `arctan` compiles to a call to `atan`, and `abs` and `arg` of a
 * `complex` (ISO/IEC 10206:1991 §6.7.6.2) to `hypot` and `atan2` -- so those
 * three were reserved, and they are the only ones of the five a Pascal
 * programmer would plausibly reach for. `main` and `_setjmp` are the others,
 * and `_setjmp` cannot move: §6.8.3.11's non-local goto needs it called in the
 * frame `longjmp` returns to, so a wrapper would return before the jump.
 *
 * The cost is one call frame apiece, `libpasrt.a` being a static archive that
 * nothing links across. These are libm calls already and `complex` is not a
 * hot path in anything here; a name a user can have is worth more.
 *
 * They take and return `double` and do nothing else -- no domain check. Every
 * one of the three is total over the reals: `atan` on all of them, `hypot` on
 * every pair, and `atan2` on every pair including (0, 0), where C defines the
 * result rather than leaving it an error. So there is nothing here for
 * pas_runtime_error to report, and adding a check would be inventing one the
 * standard does not have. */

double pas_atan(double x) { return atan(x); }
double pas_atan2(double y, double x) { return atan2(y, x); }
double pas_hypot(double x, double y) { return hypot(x, y); }

/* ------------------------------------------------------------------- files */

/* ISO 7185 §6.4.3.5 gives every file variable a buffer variable `f^` and
 * defines `get` and `put` on it; `read` and `write` are *derived* from those.
 * This runtime keeps that structure rather than flattening it: the primitives
 * below are the real ones, and everything else is written in terms of them.
 *
 * That is not pedantry. The buffer variable is one character of lookahead, and
 * a lexer — the first thing the self-hosted compiler needs — is exactly the
 * program that wants to inspect the next character without consuming it.
 *
 * A `file of T` is the same machine with two constants changed: the component
 * is `compsize` bytes rather than one, and there is no line structure. The
 * lookahead becomes "the buffer holds the component the file is positioned
 * at", which is what `have` already meant — so `get`, `put`, `eof` and the
 * buffer variable are one implementation with a text branch, not two. */

/* ISO/IEC 10206:1991 §6.4.3.6 gives a file exactly three modes: Inspection,
 * Generation and Update. The third is reachable only through SeekUpdate, and
 * only for a direct-access file — reset and rewrite have no update variant. */
enum { PAS_CLOSED = 0, PAS_READING = 1, PAS_WRITING = 2, PAS_UPDATING = 3 };

struct pas_file {
  FILE *fp;
  int mode;
  int binding;   /* one of the PAS_BIND_* constants */
  int arg;       /* which command-line argument, when binding is PAS_BIND_ARG */
  int lookahead; /* text: the raw character, or EOF; only when `have` */
  int have;      /* the buffer variable holds the current component */
  int istext;    /* a `text`, with line structure; not a `file of char` */
  /* ISO/IEC 10206:1991 §6.4.3.6: the file-type had an index-type. It changes
   * exactly one thing about an ordinary file — the stream is opened for both
   * reading and writing, because `SeekUpdate` may turn a file being read into
   * one being written without reopening it. */
  int direct;
  /* ISO/IEC 10206:1991 §6.7.5.6: the external entity this variable is bound
   * to, if any. A *bound* file names its own external file, where a program
   * parameter names an argument and a scratch file names nothing — so this is
   * a third answer to the question `pas_external` asks, and the only one the
   * running program chooses for itself. */
  char *bound_name;
  /* ISO/IEC 10206:1991 §6.7.5.5: the auxiliary `text` variable readstr and
   * writestr are defined in terms of is backed by memory rather than by a
   * stream the operating system named. `membuf` is that memory — the copy of
   * the string-expression readstr reads from, or the buffer open_memstream
   * grows for writestr — and `memlen` is the length open_memstream reports.
   * Every other field means what it always did, which is the whole point:
   * the read and write primitives are reused unchanged (ADR-0060). */
  char *membuf;
  size_t memlen;
  int compsize;  /* the size of one component in bytes; 1 for a text */
  int ateof;     /* non-text: the fetch that filled `have` found no component */
  char ch;       /* the buffer variable of a text file */
  /* ISO 7185 §6.9.1 c) and d) read the *longest* prefix that forms a number:
   * "s shall, and s ~ S(t.first) shall not, form a signed-integer" — so `1.`
   * is the integer 1 followed by a point, because `1.` is not an unsigned-real
   * (§6.1.5 requires digits after the point). A file offers one character of
   * lookahead (ADR-0021) and that is one short of deciding: the point has to
   * be consumed before the character after it can be seen. These two are where
   * an over-read is given back, most recent first — at most a point, or an
   * `e` and the sign that followed it. */
  char pushback[2];
  unsigned char npush;
  /* ISO 7185 §6.9.5: `page(f)` performs an implicit `writeln(f)` "if f.L is
   * not empty and if f.L.last is not the end-of-line component" — so the
   * one thing it needs to know is whether the current line has anything on
   * it. Nothing else in the runtime tracked that, because nothing else
   * needed it. A zero field width may write no characters at all
   * (§6.10.3.1), which is why this follows what was *written* rather than
   * merely that a write was attempted. */
  /* It serves the *reading* direction too, and means the same thing there:
   * ISO 7185 §6.6.5.2's post-assertion for `reset(f)` appends an end-of-line
   * when f is a text, its contents are not empty, and the last component is
   * not one already. A stream cannot be asked for its last byte, so the
   * end-of-line is produced where the read reaches EOF — which is the same
   * file, one component later. Starting at 1 is what makes an *empty* file
   * get nothing, the clause requiring the contents to be non-empty. */
  int atbol;     /* the file is positioned at the start of a line */
  void *buf;     /* the buffer variable f^: &ch for a text, else allocated */
  const char *name; /* what to call this file in a diagnostic */
  /* Every open file, most recent first. A block exit unlinks the files it
   * declared; a non-local `goto` unlinks and closes every file a block entry
   * registered after the target block's activation began, which is the
   * obligation the epilogue would otherwise have discharged (ADR-0032). File
   * lifetimes nest, so "registered later" and "abandoned" are the same set. */
  struct pas_file *prev_open, *next_open;
};

static struct pas_file *pas_open_files;

static void pas_link_open(struct pas_file *f) {
  f->prev_open = NULL;
  f->next_open = pas_open_files;
  if (pas_open_files)
    pas_open_files->prev_open = f;
  pas_open_files = f;
}

static void pas_unlink_open(struct pas_file *f) {
  if (f->prev_open)
    f->prev_open->next_open = f->next_open;
  else if (pas_open_files == f)
    pas_open_files = f->next_open;
  if (f->next_open)
    f->next_open->prev_open = f->prev_open;
  f->prev_open = NULL;
  f->next_open = NULL;
}

_Static_assert(sizeof(struct pas_file) <= PAS_FILE_SIZE,
               "PAS_FILE_SIZE is smaller than struct pas_file");

static int pas_argc;
static char **pas_argv;

void pas_args(int argc, char **argv) {
  pas_argc = argc;
  pas_argv = argv;
}

/* Files opened during the run, so the program's exit can flush them. A file
 * variable is closed when its block exits (the compiler emits pas_file_done),
 * which is ISO's rule; this list only catches the standard files and anything
 * still open at exit. */
static void pas_check_open(struct pas_file *f, int mode, const char *op) {
  /* §6.7.5.2 lets Update stand in for both: `get` accepts "Inspection or
   * Update" and `put` accepts a direct-access file in either writing mode, so
   * a file being updated answers to whichever question is asked of it. */
  if (f->mode != mode && f->mode != PAS_UPDATING)
    pas_error2(op, f->mode == PAS_CLOSED ? " a file that is not open"
                                         : " a file open in the other mode");
}

/* --- direct access (§6.7.5.2, §6.7.6.6) ----------------------------------
 *
 * A direct-access file is the sequential machine with one number added: the
 * component the next operation acts on. Everything about it is expressed in
 * *components* rather than bytes, because that is the unit §6.4.3.6 gives the
 * index-type — the byte offset is `compsize` times the position and appears
 * nowhere else.
 *
 * The compiler passes positions already relative to the index-type's smallest
 * value, so the runtime never sees an ordinal: `SeekRead(f, 'c')` on a
 * `file [char] of T` arrives here as 99. That is the same division of labour
 * the array code has, where the lower bound is folded into the offset. */

static void pas_check_direct(struct pas_file *f, const char *op) {
  if (!f->fp || f->mode == PAS_CLOSED)
    pas_error2(op, " a file that is not open");
}

/* The number of components the file holds. §6.7.6.6's LastPosition and
 * `empty` are both this question; so is the pre-assertion of the three Seek
 * procedures, which allow seeking to exactly one past the last component. */
static long pas_length(struct pas_file *f) {
  long here = ftell(f->fp);
  long end;
  fflush(f->fp);
  if (fseek(f->fp, 0, SEEK_END) != 0)
    pas_runtime_error("cannot measure the file");
  end = ftell(f->fp);
  if (fseek(f->fp, here, SEEK_SET) != 0)
    pas_runtime_error("cannot measure the file");
  return end / f->compsize;
}

/* §6.7.5.2: the three seeks differ only in the mode they leave the file in and
 * in whether they preload the buffer variable. The shared pre-assertion is
 * `0 <= ord(n)-ord(a) <= length(f)`, so seeking one past the end is legal —
 * that is the append position, and refusing it would make SeekWrite unable to
 * add a component. */
static void pas_seek(void *v, int n, int mode, const char *op) {
  struct pas_file *f = v;
  long len;
  pas_check_direct(f, op);
  if (n < 0)
    pas_error2(op, " a position before the start of the file");
  fflush(f->fp);
  len = pas_length(f);
  if ((long)n > len)
    pas_error2(op, " a position past the end of the file");
  if (fseek(f->fp, (long)n * f->compsize, SEEK_SET) != 0)
    pas_error2(op, " a position the operating system refused");
  /* The lookahead belongs to the old position, so it is dropped whatever the
   * new mode is; a read or update then refills it from where we now are. */
  f->have = 0;
  f->ateof = 0;
  f->npush = 0;
  f->mode = mode;
}

void pas_seekread(void *v, int n) { pas_seek(v, n, PAS_READING, "seeking to"); }
void pas_seekwrite(void *v, int n) { pas_seek(v, n, PAS_WRITING, "seeking to"); }
void pas_seekupdate(void *v, int n) {
  pas_seek(v, n, PAS_UPDATING, "seeking to");
}

/* §6.7.6.6: "position(f) = succ(a, length(f.L))" — how many components lie
 * before the current one. The lookahead complicates it: filling the buffer
 * reads a component, so the stream is one ahead of where the program is. */
int pas_position(void *v) {
  struct pas_file *f = v;
  long at;
  pas_check_direct(f, "asking the position of");
  fflush(f->fp);
  at = ftell(f->fp) / f->compsize;
  if (f->have && f->mode != PAS_WRITING)
    at -= 1;
  return (int)at;
}

/* §6.7.6.6: "LastPosition(f) = succ(a, length(f.L~f.R)-1)", and "it shall be
 * an error if no such value exists" — which is exactly the empty file, where
 * there is no last component to name. */
int pas_lastposition(void *v) {
  struct pas_file *f = v;
  long len;
  pas_check_direct(f, "asking the last position of");
  fflush(f->fp);
  len = pas_length(f);
  if (len == 0)
    pas_runtime_error("lastposition of an empty file");
  return (int)(len - 1);
}

int pas_empty(void *v) {
  struct pas_file *f = v;
  pas_check_direct(f, "asking whether it is empty");
  fflush(f->fp);
  return pas_length(f) == 0;
}

/* §6.7.5.2's `update(f)`: write the buffer variable back over the component
 * the file is positioned at, and *do not advance* — `f.L = f0.L` is the whole
 * difference from `put`, and it is what makes read-modify-write possible. */
void pas_update(void *v) {
  struct pas_file *f = v;
  long at;
  pas_check_direct(f, "updating");
  if (f->mode != PAS_UPDATING && f->mode != PAS_WRITING)
    pas_runtime_error("update needs a file opened with SeekUpdate");
  fflush(f->fp);
  at = ftell(f->fp) / f->compsize;
  if (f->have)
    at -= 1; /* the lookahead already consumed the component being replaced */
  if (fseek(f->fp, at * f->compsize, SEEK_SET) != 0)
    pas_runtime_error("cannot position the file to update it");
  if (fwrite(f->buf, 1, (size_t)f->compsize, f->fp) != (size_t)f->compsize)
    pas_runtime_error("cannot write to the file");
  fflush(f->fp);
  /* ...and back, because the position must not move. */
  if (fseek(f->fp, at * f->compsize, SEEK_SET) != 0)
    pas_runtime_error("cannot position the file after updating it");
  f->have = 0;
}

/* The external file a variable stands for, or a diagnostic if the program was
 * not given one. */
static const char *pas_external(struct pas_file *f) {
  /* A binding made by the program wins over the one the command line gave:
   * §6.7.5.6's `bind` is what a program uses to name a file it was not
   * started with, and §6.12 binds the program-parameters before it runs. */
  if (f->bound_name)
    return f->bound_name;
  if (f->arg >= pas_argc) {
    char msg[128];
    snprintf(msg, sizeof msg,
             "the program parameter '%s' needs a file name as argument %d",
             f->name ? f->name : "?", f->arg);
    pas_runtime_error(msg);
  }
  return pas_argv[f->arg];
}

void pas_file_init(void *v, int binding, int arg, const char *name,
                   int compsize, int istext, int direct) {
  struct pas_file *f = v;
  f->fp = NULL;
  f->mode = PAS_CLOSED;
  f->binding = binding;
  f->arg = arg;
  f->lookahead = EOF;
  f->have = 0;
  f->istext = istext;
  f->direct = direct;
  f->compsize = compsize > 0 ? compsize : 1;
  f->ateof = 0;
  f->ch = ' ';
  f->npush = 0;
  /* A file nothing has been written to is at the start of a line, which is
   * what makes `page` as the first statement write one form feed and no
   * blank line before it (§6.9.5). */
  f->atbol = 1;
  f->name = name;
  f->bound_name = NULL;
  f->membuf = NULL;
  f->memlen = 0;
  /* The buffer variable of a text file is the one character `ch` already
   * there; a `file of T` needs T's worth of storage, and malloc is what
   * guarantees it is aligned for any T. It is freed when the block that
   * declared the file exits, which is where pas_file_done is called. */
  if (istext) {
    f->buf = &f->ch;
  } else {
    f->buf = calloc(1, (size_t)f->compsize);
    if (!f->buf)
      pas_runtime_error("out of memory for a file buffer variable");
  }
  pas_link_open(f);
  /* ISO 7185 §6.10: `input` is reset and `output` rewritten before the program
   * body runs. The lookahead is deliberately *not* fetched here — a program
   * that never reads must not block waiting for a terminal. */
  if (binding == PAS_BIND_INPUT) {
    f->fp = stdin;
    f->mode = PAS_READING;
  } else if (binding == PAS_BIND_OUTPUT) {
    f->fp = stdout;
    f->mode = PAS_WRITING;
  }
}

/* Closing is what a block exit does to the files declared in it. The standard
 * files are left alone: the process owns them, not the block. */
void pas_file_done(void *v) {
  struct pas_file *f = v;
  pas_unlink_open(f);
  if (f->fp) {
    if (f->binding == PAS_BIND_INPUT || f->binding == PAS_BIND_OUTPUT) {
      fflush(f->fp);
      /* The process owns the standard files, and `ch` is not ours to free.
       *
       * Returning here rather than closing is load-bearing for a second
       * reason since modules landed: ISO/IEC 10206:1991 6.2.3.6 terminates the
       * main-program-block before the finalization of any module, so `main`
       * runs this over `output` and a module's `to end do` writes to it
       * afterwards. Closing would make that write undefined.
       * tests/extended/module.pas and module_order.pas both do it. */
      return;
    }
    fclose(f->fp);
    f->fp = NULL;
    f->mode = PAS_CLOSED;
  }
  if (f->buf && f->buf != &f->ch) {
    free(f->buf);
    f->buf = NULL;
  }
}

void pas_reset(void *v) {
  struct pas_file *f = v;
  /* §6.11.4.2 (and ISO 7185 §6.10) make the effect of `reset` on the required
   * file `input` implementation-defined, and the standard input cannot be
   * repositioned. Clearing the buffer here does not merely fail to rewind —
   * it *loses a character*: ADR-0021's lookahead means `f^` may already hold
   * one the stream has consumed, and once it is dropped nothing can read it
   * again. So the definition is that `reset(input)` leaves the file exactly as
   * it is, which is the only effect available that does not destroy input.
   * `doc/implementation-defined.md` states it, and `tests/resetinput.pas`
   * pins it. */
  if (f->binding == PAS_BIND_INPUT) {
    f->fp = stdin;
    f->mode = PAS_READING;
    return;
  }
  f->have = 0;
  f->lookahead = EOF;
  f->ateof = 0;
  f->ch = ' ';
  /* Nothing has been delivered from the new position, so it is the start of a
   * line -- which is what makes an empty file get no end-of-line appended. */
  f->atbol = 1;
  /* A character given back by a number read belongs to the position it was
   * read from, so it dies with the position. `reset(input)` returns above
   * without reaching here, which is what keeps ADR-0073's promise that it
   * loses nothing. */
  f->npush = 0;
  switch (f->binding) {
  case PAS_BIND_INPUT: break; /* answered above */
  case PAS_BIND_OUTPUT:
    pas_runtime_error("reset applied to the standard output");
    break;
  case PAS_BIND_ARG: {
    const char *name = pas_external(f);
    if (f->fp)
      fclose(f->fp);
    /* The component of a `file of T` is T's machine representation, so the
     * stream must not be translated on a platform that would. */
    /* A direct-access file may be sought into and updated afterwards, so it
     * is opened for both from the start — `SeekUpdate` is not allowed to
     * reopen, since §6.7.5.2 requires it to preserve the contents. */
    f->fp = fopen(name, f->direct ? "r+b" : f->istext ? "r" : "rb");
    if (!f->fp)
      pas_error2("cannot open for reading: ", name);
    break;
  }
  default: /* an internal file: reread what rewrite wrote */
    if (!f->fp)
      f->fp = tmpfile();
    else {
      fflush(f->fp);
      rewind(f->fp);
    }
    if (!f->fp)
      pas_runtime_error("cannot create a temporary file");
    break;
  }
  f->mode = PAS_READING;
}

void pas_rewrite(void *v) {
  struct pas_file *f = v;
  f->have = 0;
  f->lookahead = EOF;
  f->ateof = 0;
  f->ch = ' ';
  /* A character given back by a number read belongs to the position it was
   * read from, so it dies with the position. `reset(input)` returns above
   * without reaching here, which is what keeps ADR-0073's promise that it
   * loses nothing. */
  f->npush = 0;
  /* `atbol` is set per branch and not here, because the branches do not agree
   * about what rewrite discards. Everywhere but the standard output the file
   * becomes empty, so the position is the start of a line; on `output` there
   * is nothing to discard -- the characters are already gone from the
   * program's reach -- and clearing it would make the next `page` write a
   * blank line into the middle of the output. `tests/rewriteoutput.pas` is
   * the program that says so, and it is why this is not one assignment. */
  switch (f->binding) {
  case PAS_BIND_INPUT:
    pas_runtime_error("rewrite applied to the standard input");
    break;
  case PAS_BIND_OUTPUT:
    f->fp = stdout;
    break;
  case PAS_BIND_ARG: {
    const char *name = pas_external(f);
    if (f->fp)
      fclose(f->fp);
    f->fp = fopen(name, f->direct ? "w+b" : f->istext ? "w" : "wb");
    if (!f->fp)
      pas_error2("cannot open for writing: ", name);
    f->atbol = 1;
    break;
  }
  default:
    if (f->fp)
      fclose(f->fp);
    f->fp = tmpfile();
    if (!f->fp)
      pas_runtime_error("cannot create a temporary file");
    f->atbol = 1;
    break;
  }
  f->mode = PAS_WRITING;
}

/* Fetch the lookahead if it is not already there. Every read-side primitive
 * starts here, which is what makes the fetch lazy: the character is read from
 * the operating system at the moment the program first asks about it, not at
 * reset. */
static void pas_fill(struct pas_file *f) {
  if (f->have)
    return;
  pas_check_open(f, PAS_READING, "reading from");
  if (!f->istext) {
    /* A partial component at the end is no component at all: the file was not
     * written by a Pascal program with this component type, and there is
     * nothing for the buffer variable to hold. */
    size_t n = fread(f->buf, 1, (size_t)f->compsize, f->fp);
    f->ateof = n != (size_t)f->compsize;
    f->have = 1;
    return;
  }
  /* A character given back by pas_unread is next, before the stream. The
   * order is most-recent-first, because an over-read is undone one character
   * at a time from the end. */
  if (f->npush) {
    f->lookahead = (unsigned char)f->pushback[--f->npush];
    f->have = 1;
    f->ateof = 0;
    f->ch = (char)f->lookahead;
    return;
  }
  f->lookahead = getc(f->fp);
  /* ISO 7185 §6.6.5.2: `reset(f)` on a text whose contents do not end in an
   * end-of-line appends one. The stream cannot be asked for its last byte, so
   * the appended component is produced here, where the read arrives at the
   * place it would occupy — and produced exactly once, because delivering it
   * puts the file at the start of a line and the next fill then sees the same
   * EOF with nothing left to add.
   *
   * `write(f, 'A'); reset(f)` is the program this is for: without it the 'A'
   * is the whole file, `eoln(f)` after reading it is D.42's error, and a
   * program that reads back what it wrote loses its last line rather than
   * being told anything. CONF067 and CONF078 of the BSI suite are that
   * program; `tests/eoln_appended.pas` is this one's. */
  if (f->lookahead == EOF && !f->atbol)
    f->lookahead = '\n';
  if (f->lookahead != EOF)
    f->atbol = f->lookahead == '\n';
  f->have = 1;
  f->ateof = f->lookahead == EOF;
  /* ISO 7185 §6.4.3.5: at the end of a line the buffer variable is a space.
   * The line marker itself is not a character the program can see. */
  f->ch = (f->lookahead == '\n' || f->lookahead == EOF)
              ? ' '
              : (char)f->lookahead;
}

int pas_eof(void *v) {
  struct pas_file *f = v;
  if (f->mode == PAS_WRITING)
    return 1; /* §6.6.6.5: eof is true for a file being written */
  pas_fill(f);
  return f->ateof;
}

/* Only a text file has lines, so Sema refuses `eoln` on any other — this is
 * reached only for a text. */
int pas_eoln(void *v) {
  struct pas_file *f = v;
  pas_fill(f);
  if (f->lookahead == EOF)
    pas_runtime_error("eoln at the end of the file");
  return f->lookahead == '\n';
}

/* The address of the buffer variable f^. For a file being read the component
 * has to be there first; for one being written the program assigns to it and
 * then calls put. The address is the same one for the file's whole life, so a
 * `file of T` whose T is a record hands back somewhere `f^.field` can index. */
void *pas_buffer(void *v) {
  struct pas_file *f = v;
  /* Update counts as reading here. §6.7.5.2's SeekUpdate post-assertion is
   * `f" = f.R.first` — the buffer variable holds the component sought to — so
   * a file in Update mode has a component to fetch, and `f^ := f^ + 1;
   * update(f)` reads the old value before writing the new one. Treating
   * Update as writing returned whatever the last `put` had left in the
   * buffer, which is a wrong answer rather than a refused one. */
  if (f->mode == PAS_READING || f->mode == PAS_UPDATING) {
    pas_fill(f);
    if (f->ateof)
      pas_runtime_error("the buffer variable is undefined at end of file");
  } else {
    pas_check_open(f, PAS_WRITING, "using the buffer variable of");
  }
  return f->buf;
}

/* ISO/IEC 10206:1991 §6.7.5.2's `extend(f)`: open for writing, positioned at
 * the end, with the contents kept. It is the one file procedure that is
 * neither reset nor rewrite, and it needs no direct-access file — appending is
 * a sequential operation. */
void pas_extend(void *v) {
  struct pas_file *f = v;
  f->have = 0;
  f->lookahead = EOF;
  f->ateof = 0;
  f->ch = ' ';
  /* A character given back by a number read belongs to the position it was
   * read from, so it dies with the position. `reset(input)` returns above
   * without reaching here, which is what keeps ADR-0073's promise that it
   * loses nothing. */
  f->npush = 0;
  switch (f->binding) {
  case PAS_BIND_INPUT:
    pas_runtime_error("extend applied to the standard input");
    break;
  case PAS_BIND_OUTPUT:
    f->fp = stdout;
    break;
  case PAS_BIND_ARG: {
    const char *name = pas_external(f);
    if (f->fp)
      fclose(f->fp);
    f->fp = fopen(name, f->direct ? "a+b" : f->istext ? "a" : "ab");
    if (!f->fp)
      pas_error2("cannot open for appending: ", name);
    break;
  }
  default:
    /* An internal file has no name to reopen, so `extend` is `rewrite` that
     * keeps what is there: seek to the end of the temporary already in hand. */
    if (!f->fp) {
      f->fp = tmpfile();
      if (!f->fp)
        pas_runtime_error("cannot create a temporary file");
    } else {
      fflush(f->fp);
      if (fseek(f->fp, 0, SEEK_END) != 0)
        pas_runtime_error("cannot position the file to extend it");
    }
    break;
  }
  f->mode = PAS_WRITING;
}

void pas_get(void *v) {
  struct pas_file *f = v;
  pas_fill(f);
  if (f->ateof)
    pas_runtime_error("get past the end of the file");
  f->have = 0; /* the next fill fetches the following component */
}

void pas_put(void *v) {
  struct pas_file *f = v;
  pas_check_open(f, PAS_WRITING, "writing to");
  /* §6.7.5.2 extends put's pre-assertion for a direct-access file: it may
   * write over a component in the middle rather than only at the end. The
   * lookahead, if one was fetched, belongs to the component being overwritten,
   * so the stream is one ahead and has to be stepped back. */
  if (f->direct && f->have) {
    long at = ftell(f->fp) / f->compsize - 1;
    fflush(f->fp);
    if (fseek(f->fp, at * f->compsize, SEEK_SET) != 0)
      pas_runtime_error("cannot position the file to write to it");
    f->have = 0;
  }
  if (f->istext)
    putc(f->ch, f->fp);
  else if (fwrite(f->buf, 1, (size_t)f->compsize, f->fp) !=
           (size_t)f->compsize)
    pas_runtime_error("cannot write to the file");
}

/* --- the derived read operations, in terms of the primitives above -------- */

char pas_read_char(void *v) {
  struct pas_file *f = v;
  char c = *(char *)pas_buffer(v); /* c := f^ */
  pas_get(v);              /* get(f)  */
  (void)f;
  return c;
}

void pas_readln(void *v) {
  struct pas_file *f = v;
  pas_fill(f);
  if (f->lookahead == EOF)
    pas_runtime_error("readln past the end of the file");
  for (;;) {
    int c = f->lookahead;
    f->have = 0;
    if (c == '\n')
      return;
    pas_fill(f);
    /* A last line with no terminator ends here rather than being an error:
     * the file has run out, and the line the program asked to finish is
     * finished. */
    if (f->lookahead == EOF)
      return;
  }
}

/* ISO 7185 §6.9.1: reading a number skips preceding blanks and line markers,
 * then reads the longest sequence of characters forming a number. */
static void pas_skip_blanks(struct pas_file *f) {
  for (;;) {
    pas_fill(f);
    if (f->lookahead == ' ' || f->lookahead == '\n' || f->lookahead == '\t') {
      f->have = 0;
      continue;
    }
    return;
  }
}

/* Give back one character that was consumed while looking for the end of a
 * number, making it the buffer variable again. Whatever the buffer variable
 * held has not been consumed by the program either, so it goes behind — which
 * is why `pushback` is a stack and not a queue. Only ever called with '.',
 * 'e', 'E', '+' or '-', so `ch` is that character rather than the space a line
 * marker would show (§6.4.3.5). */
static void pas_unread(struct pas_file *f, char c) {
  if (f->have && f->lookahead != EOF) {
    /* Two is the deepest an over-read goes: `e` and the sign after it. */
    f->pushback[f->npush++] = (char)f->lookahead;
  }
  f->lookahead = (unsigned char)c;
  f->have = 1;
  f->ateof = 0;
  f->ch = c;
}

long long pas_read_int(void *v) {
  struct pas_file *f = v;
  int negative = 0;
  long long value = 0;
  int digits = 0;

  pas_skip_blanks(f);
  if (f->lookahead == '+' || f->lookahead == '-') {
    negative = f->lookahead == '-';
    f->have = 0;
    pas_fill(f);
  }
  while (f->lookahead >= '0' && f->lookahead <= '9') {
    value = value * 10 + (f->lookahead - '0');
    /* The integer type is -maxint..maxint (ADR-0014), so a number too big for
     * it is an error rather than a wrapped value. */
    if (value > 2147483647LL)
      pas_runtime_error("integer read is outside -maxint..maxint");
    ++digits;
    f->have = 0;
    pas_fill(f);
  }
  if (!digits)
    pas_runtime_error("expected an integer in the input");
  return negative ? -value : value;
}

/* The characters of the number being read.
 *
 * §6.1.5 puts no bound on a digit-sequence, so neither can this. It was a
 * `char buf[64]` and every loop below carried `n + 1 < sizeof buf` -- which
 * stopped the *loop* and not the *read*, leaving the digits past the
 * sixty-third in the file to become the next value the program read. A
 * seventy-digit number was read as its first sixty-three digits and the input
 * was silently desynchronised from there on; `tests/readlongreal.pas` is the
 * program that shows it, and `pas_read_int` had always reported its own
 * overflow rather than truncating.
 *
 * The small buffer is the whole of the common case -- no number a program
 * means to write reaches it -- and the heap is only for the pathological one,
 * which is why this is not simply a malloc. */
struct pas_numbuf {
  char *p;
  size_t n, cap;
  char small[64];
};

static void pas_numbuf_init(struct pas_numbuf *b) {
  b->p = b->small;
  b->n = 0;
  b->cap = sizeof b->small;
}

/* One character, with room kept for the terminator strtod needs -- so `n` is
 * always a legal index and the caller never checks. */
static void pas_numbuf_put(struct pas_numbuf *b, char c) {
  if (b->n + 1 >= b->cap) {
    size_t want = b->cap * 2;
    char *grown = b->p == b->small ? malloc(want) : realloc(b->p, want);
    if (!grown)
      pas_runtime_error("out of memory reading a number");
    if (b->p == b->small)
      memcpy(grown, b->small, b->n);
    b->p = grown;
    b->cap = want;
  }
  b->p[b->n++] = c;
}

static void pas_numbuf_done(struct pas_numbuf *b) {
  if (b->p != b->small)
    free(b->p);
}

double pas_read_real(void *v) {
  struct pas_file *f = v;
  struct pas_numbuf buf;
  int digits = 0;
  double result;

  pas_numbuf_init(&buf);
  pas_skip_blanks(f);
  if (f->lookahead == '+' || f->lookahead == '-') {
    pas_numbuf_put(&buf, (char)f->lookahead);
    f->have = 0;
    pas_fill(f);
  }
  while (f->lookahead >= '0' && f->lookahead <= '9') {
    pas_numbuf_put(&buf, (char)f->lookahead);
    ++digits;
    f->have = 0;
    pas_fill(f);
  }
  /* §6.1.5 makes both halves obligatory: `unsigned-real = digit-sequence '.'
   * fractional-part [...]`, so `1.` is not a signed-number and neither is
   * `.5`. The point therefore belongs to whatever follows unless digits stand
   * on both sides of it — and it has to be consumed to find out what is on the
   * right, which is what the give-back is for. */
  if (f->lookahead == '.' && digits) {
    f->have = 0;
    pas_fill(f);
    if (f->lookahead >= '0' && f->lookahead <= '9') {
      pas_numbuf_put(&buf, '.');
      while (f->lookahead >= '0' && f->lookahead <= '9') {
        pas_numbuf_put(&buf, (char)f->lookahead);
        ++digits;
        f->have = 0;
        pas_fill(f);
      }
    } else {
      pas_unread(f, '.');
    }
  }
  /* The same for the scale factor: `scale-factor = [ sign ] digit-sequence`,
   * so `2e` and `2e+` are the integer 2 followed by characters the program has
   * not read yet. Up to two are given back, and the order matters — the sign
   * has to come out before the character that followed it. */
  if ((f->lookahead == 'e' || f->lookahead == 'E') && digits) {
    /* The `e` given back has to be the one that was written: §6.1.5 admits
     * either case, and the program reads the character, not its meaning. */
    char exp = (char)f->lookahead;
    char sign = '\0';
    f->have = 0;
    pas_fill(f);
    if (f->lookahead == '+' || f->lookahead == '-') {
      sign = (char)f->lookahead;
      f->have = 0;
      pas_fill(f);
    }
    if (f->lookahead >= '0' && f->lookahead <= '9') {
      pas_numbuf_put(&buf, 'e');
      if (sign)
        pas_numbuf_put(&buf, sign);
      while (f->lookahead >= '0' && f->lookahead <= '9') {
        pas_numbuf_put(&buf, (char)f->lookahead);
        f->have = 0;
        pas_fill(f);
      }
    } else {
      if (sign)
        pas_unread(f, sign);
      pas_unread(f, exp);
    }
  }
  if (!digits) {
    pas_numbuf_done(&buf);
    pas_runtime_error("expected a number in the input");
  }
  buf.p[buf.n] = '\0';
  result = strtod(buf.p, NULL);
  pas_numbuf_done(&buf);
  return result;
}

/* ------------------------------------------------------------------ output */

static FILE *pas_out(void *v) {
  struct pas_file *f = v;
  pas_check_open(f, PAS_WRITING, "writing to");
  return f->fp;
}

void pas_write_int(void *v, long long val, int width) {
  FILE *o = pas_out(v);
  /* §6.10.3.3 b): a TotalWidth of zero is not "suppress" — 0 is always less
   * than IntDigits + 1, so what is written is the sign and the digits, which
   * is what a zero field width means to printf too. */
  if (width < 0) fprintf(o, "%lld", val);
  else fprintf(o, "%*lld", width, val);
  ((struct pas_file *)v)->atbol = 0; /* a number is never no characters */
}

/* ISO/IEC 10206:1991 §6.10.3.6, and ISO 7185 §6.9.3.6 before it: a string of
 * length n written with a field width is padded on the left when TotalWidth
 * exceeds n, *truncated to its first TotalWidth characters* when
 * 1 <= TotalWidth <= n, and written as no characters at all when TotalWidth is
 * zero — the last of which is Extended Pascal's addition, since ISO 7185
 * required TotalWidth >= 1. The truncation is not new: it was always the
 * rule, and this runtime did not honour it.
 *
 * §6.10.3.5 makes a Boolean "equivalent to writing the appropriate
 * character-string 'True' or 'False' ... with a field-width parameter of
 * TotalWidth", so it is the same three cases and the same code. */
static void pas_write_padded(FILE *o, const char *s, int len, int width) {
  if (width < 0) { /* no width given: the default is the string's own length */
    fwrite(s, 1, (size_t)len, o);
    return;
  }
  if (width > len) {
    int pad = width - len;
    while (pad-- > 0) putc(' ', o);
    fwrite(s, 1, (size_t)len, o);
    return;
  }
  fwrite(s, 1, (size_t)width, o); /* width == 0 writes nothing */
}

void pas_write_real(void *v, double val, int width, int prec) {
  FILE *o = pas_out(v);
  /* ISO 7185 §6.9.5's `page` needs to know whether the current line has
   * anything on it, and every other write primitive says so. This one did not,
   * so a real was the one value that could be written and leave the line
   * looking empty -- `write(1.5); page` then wrote the form feed with no line
   * terminator before it. Unconditional, unlike the char and Boolean cases:
   * both forms below always write at least one character, the fixed-point one
   * because a digit and a point are not suppressible and the floating-point
   * one because ActWidth is clamped to ExpDigits + 6 further down.
   * `tests/page_after_real.pas` is the program that says so. */
  ((struct pas_file *)v)->atbol = 0;
  if (prec >= 0) {
    /* Fixed-point form, §6.10.3.4.2. Its representation ends with "the
     * character '.', the next FracDigits digit-characters", and the '.' is
     * unconditional — so a FracDigits of zero, which Extended Pascal made
     * legal, still writes it, where C's "%.0f" does not. MinNumChars counts
     * that character, which is why the padding is computed around it. */
    if (prec == 0) {
      int pad = width - (snprintf(NULL, 0, "%.0f", val) + 1);
      while (pad-- > 0) putc(' ', o);
      fprintf(o, "%.0f.", val);
    } else if (width < 0) {
      fprintf(o, "%.*f", prec, val);
    } else {
      fprintf(o, "%*.*f", width, prec, val);
    }
    return;
  }
  /* Floating-point form, §6.10.3.4.1. ExpDigits is implementation-defined and
   * here it is what the exponent needs — two digits, or three past 1e100,
   * which is what C's %E writes. DecPlaces is then ActWidth - ExpDigits - 5,
   * so the representation is exactly ActWidth characters wide and the width
   * needs no padding of its own. The space flag supplies §6.10.3.4.1's sign
   * character, which is a space rather than nothing for a positive value.
   *
   * With no width given the default TotalWidth is implementation-defined
   * (E.24); it is ExpDigits + 17 here, which is what makes DecPlaces 12
   * whatever the exponent costs. */
  int expDigits = 2;
  if (val != 0.0 && !isnan(val) && !isinf(val)) {
    /* The exponent written is floor(log10(|val|)) -- the one `%E` prints --
     * and *not* the magnitude of log10, which is what this asked for until
     * `tests/extended/writereal_width.pas` was written. The two differ for a
     * value in [1e-100, 1e-99): log10(9.99e-100) is -99.0004, so the magnitude
     * is under 100 while the printed exponent is E-100. Budgeting two digits
     * for a three-digit exponent made the representation one character wider
     * than TotalWidth, which is the one thing §6.10.3.4.1 fixes.
     *
     * Rounding in log10 can only move this by one, and it is safe in that
     * direction: an ExpDigits that is one too *large* makes DecPlaces one too
     * small, and the field width then pads the difference, so the
     * representation is still exactly ActWidth characters. One too small is
     * what overflows the field, and floor is what cannot produce it. */
    int e10 = (int)floor(log10(fabs(val)));
    if (e10 >= 100 || e10 <= -100)
      expDigits = 3;
  }
  int actWidth = width < 0 ? expDigits + 17 : width;
  if (actWidth < expDigits + 6) actWidth = expDigits + 6;
  fprintf(o, "% *.*E", actWidth, actWidth - expDigits - 5, val);
}

void pas_write_bool(void *v, int val, int width) {
  const char *s = val ? "TRUE" : "FALSE";
  pas_write_padded(pas_out(v), s, val ? 4 : 5, width);
  if (width != 0) ((struct pas_file *)v)->atbol = 0;
}

void pas_write_char(void *v, char c, int width) {
  FILE *o = pas_out(v);
  /* §6.10.3.2: "if TotalWidth = 0, no characters." */
  if (width == 0) return;
  if (width < 0) putc(c, o);
  else fprintf(o, "%*c", width, c);
  ((struct pas_file *)v)->atbol = 0;
}

void pas_write_str(void *v, const char *s, int len, int width) {
  pas_write_padded(pas_out(v), s, len, width);
  if (width != 0 && !(width < 0 && len == 0))
    ((struct pas_file *)v)->atbol = 0;
}

void pas_writeln(void *v) {
  putc('\n', pas_out(v));
  ((struct pas_file *)v)->atbol = 1;
}

/* ISO 7185 §6.9.5. The effect on the file is implementation-defined — "such
 * that subsequent text written to f will be on a new page if the textfile is
 * printed on a suitable device" — and here it is the ASCII form feed, which
 * is what a printer and every other Pascal mean by it.
 *
 * What the standard does fix is the rest: the pre-assertion is `writeln(f)`'s,
 * which `pas_out` checks; the implicit `writeln` happens only when the line
 * has something on it; and the buffer variable becomes totally-undefined,
 * which here is the lookahead being dropped. */
void pas_page(void *v) {
  struct pas_file *f = v;
  FILE *o = pas_out(v);
  if (!f->atbol) putc('\n', o);
  putc('\f', o);
  f->atbol = 1;
  f->have = 0;
}

/* -------------------------------------------------- the non-local goto ---- */

/* ISO 7185 §6.8.2.4 lets a `goto` name a label in an enclosing block, which
 * abandons every activation between here and the target. Two things have to
 * happen, in this order: the abandoned blocks' files are closed, and then the
 * stack is cut back.
 *
 * The buffer is opaque to the compiler exactly as a file variable is — it
 * alloca's PAS_JUMP_SIZE bytes in the target's activation record and passes
 * their address. `jmp_buf` is the platform's business, and the one thing the
 * compiler cannot do through this interface is call `_setjmp` for us: a
 * wrapper that called it would have returned by the time the jump arrives, so
 * its frame would be gone. Hence pas_jump_env, which arms the record and hands
 * back the address the generated code calls `_setjmp` on itself. */

struct pas_jump {
  struct pas_file *mark; /* the open-file list as it stood when armed */
  int active;            /* the block that owns this record has not exited */
  jmp_buf env;
};

_Static_assert(sizeof(struct pas_jump) <= PAS_JUMP_SIZE,
               "PAS_JUMP_SIZE is smaller than struct pas_jump");

void *pas_jump_env(void *v) {
  struct pas_jump *j = v;
  j->mark = pas_open_files;
  j->active = 1;
  return &j->env;
}

void pas_jump_done(void *v) {
  struct pas_jump *j = v;
  j->active = 0;
}

/* The jump itself. `id` is the label's number plus one, because `_longjmp`
 * with zero would arrive at the `_setjmp` looking like the ordinary entry. */
void pas_jump_go(void *v, int id) {
  struct pas_jump *j = v;
  struct pas_file *f;

  /* The static chain reaches only activations that are still alive, so this
   * cannot fire for a program the compiler accepted — it fires if that
   * reasoning is ever wrong, rather than jumping into a dead frame. */
  if (!j->active)
    pas_runtime_error("goto to a block that is no longer active");

  /* Close what the jump abandons, from the most recent back to the mark. The
   * epilogue of each of those blocks is about to be skipped, and this is the
   * work it would have done. */
  f = pas_open_files;
  while (f && f != j->mark) {
    struct pas_file *next = f->next_open;
    pas_file_done(f);
    f = next;
  }
  _longjmp(j->env, id);
}

/* ------------------------------------------------------- strings and memory */

/* Compare two strings of equal length, character by character, as ISO 7185
 * §6.7.2.5 defines the relational operators on the string types. memcmp is
 * exactly this ordering because char is unsigned here and every Pascal char
 * has an ordinal in 0..255. */
int pas_str_compare(const char *a, const char *b, int len) {
  return memcmp(a, b, (size_t)len);
}

/* `new` and `dispose`. The storage is zeroed: ISO 7185 leaves a fresh
 * variable undefined, so a program may not rely on this, but a deterministic
 * value makes a program that does rely on it fail the same way every run
 * instead of differently on each. */
void *pas_new(long long size) {
  void *p = calloc(1, size > 0 ? (size_t)size : 1);
  if (!p) {
    fflush(stdout);
    fprintf(stderr, "runtime error: out of memory in new\n");
    exit(1);
  }
  return p;
}

void pas_dispose(void *p) { free(p); }

/* --- binding (§6.7.5.6, §6.7.6.8) -----------------------------------------
 *
 * §6.7.5.6 leaves the binding itself implementation-defined; here it is the
 * name of an external file. That is the one external entity this compiler has
 * a meaning for, and it is what makes `bind` the answer to a question ISO 7185
 * could not ask: a program that names a file while it is running rather than
 * being handed one before it starts. */

void pas_bind(void *v, const char *name, int len) {
  struct pas_file *f = v;
  if (f->bound_name)
    pas_runtime_error("bind: the variable is already bound");
  /* §6.4.6's trailing spaces come with a fixed-string name, and a file name
   * ending in them is never what was meant. The length is the value's, so a
   * variable-string that really ends in a space keeps it. */
  while (len > 0 && name[len - 1] == ' ')
    len--;
  f->bound_name = malloc((size_t)len + 1);
  if (!f->bound_name)
    pas_runtime_error("out of memory in bind");
  memcpy(f->bound_name, name, (size_t)len);
  f->bound_name[len] = '\0';
  /* NOTE 1: "The procedure bind may change the state of the variable that is
   * to be bound in an implementation-defined way." Closing is that change:
   * whatever the variable was reading or writing, it is not this file. */
  if (f->fp && f->binding == PAS_BIND_ARG) {
    fclose(f->fp);
    f->fp = NULL;
  }
  f->mode = PAS_CLOSED;
  f->have = 0;
  f->ateof = 0;
  f->npush = 0;
  /* §6.7.5.6 makes a bound file-variable bindable, and §6.10's binding of a
   * program parameter is what this replaces — so it becomes one. */
  f->binding = PAS_BIND_ARG;
}

/* §6.7.5.6: "If the attempt is successful, the variable shall become
 * totally-undefined." NOTE 7 permits it on a variable that is not bound, so
 * there is nothing to report when there was nothing to undo. */
/* ISO/IEC 10206:1991 6.7.5.7: "Following execution of the control procedure
 * halt within an activation of a program, no further processing (see 3.6) of
 * the activation of the program shall occur."
 *
 * A halt leaves every block on the way out without running its epilogue, so
 * the files those blocks declared are closed here instead — the same
 * obligation ADR-0032's non-local goto discharges, and through the same list,
 * because "still open" and "abandoned" are the same set once nothing further
 * will run.
 *
 * The status is the *extension* (ADR-0084). §6.7.5.7's halt takes no
 * parameters and neither standard models a process exit status at all, so a
 * conforming program reaches this with 0 and cannot tell the difference. What
 * it buys is a program that can report failure to whatever invoked it, which
 * a compiler written in Pascal has to be able to do. */
void pas_halt(int status) {
  /* pas_file_done unlinks every file it is given -- the standard ones too,
   * before it returns early without closing them -- so this walks the list by
   * saving the next pointer first, exactly as pas_jump_go does. Taking the
   * head each time would work for the ordinary files and loop forever if a
   * file were ever left linked. */
  struct pas_file *f = pas_open_files;
  while (f) {
    struct pas_file *next = f->next_open;
    pas_file_done(f);
    f = next;
  }
  fflush(NULL);
  exit(status);
}

void pas_unbind(void *v) {
  struct pas_file *f = v;
  if (f->fp && f->binding == PAS_BIND_ARG) {
    fclose(f->fp);
    f->fp = NULL;
  }
  free(f->bound_name);
  f->bound_name = NULL;
  /* §6.7.5.6: "If the attempt is successful, the variable shall become
   * totally-undefined" — and not bound to anything, which has to include the
   * binding §6.12 made before the program started. Clearing this is what makes
   * `binding(f).bound` false afterwards for a program-parameter as well as for
   * a file the program bound itself, and it is why the field is cleared rather
   * than left at PAS_BIND_ARG: `pas_bind` sets that to mean "bound to a name",
   * so the two senses of the constant are only told apart by `bound_name`
   * being present. A later `reset` therefore opens a scratch file, which is
   * what an unbound file variable is. */
  f->binding = PAS_BIND_INTERNAL;
  f->arg = 0;
  f->mode = PAS_CLOSED;
  f->have = 0;
  f->ateof = 0;
  f->npush = 0;
}

/* §6.7.6.8: "If the variable is bound to an external entity, the value of
 * binding(f).bound shall be true". The name comes back with it, which is what
 * lets the standard's own example read a name into `b.name` and hand the whole
 * record to `bind`.
 *
 * A binding the *program* made is not the only kind. NOTE 2 of that clause says
 * the value returned "can also be used to determine the result of any binding
 * of program-parameters prior to activation of the main program (see 6.12)" —
 * so a program-parameter that was given a command-line argument is bound, and
 * its name is that argument. That is what lets a program read its own command
 * line, which is otherwise something neither standard offers: §6.10 and §6.12
 * bind the parameters before the program starts and give it no other channel.
 *
 * The three questions have one answer between them, so they share one. */
static const char *pas_bound_to(struct pas_file *f) {
  /* A binding the program made wins, as it does in `pas_external`: §6.7.5.6's
   * `bind` is a program naming a file it was not started with. */
  if (f->bound_name)
    return f->bound_name;
  if (f->binding == PAS_BIND_ARG && f->arg < pas_argc)
    return pas_argv[f->arg];
  /* PAS_BIND_INPUT and PAS_BIND_OUTPUT are bound to an external entity too,
   * and §6.7.6.8 makes the *value* implementation-defined. The standard files
   * have no name in the file system to report, and inventing one would be a
   * name `bind` could not reproduce, so they answer as unbound —
   * doc/implementation-defined.md states it. A program-parameter with no
   * argument (PAS_BIND_ARG at or past argc) is genuinely unbound, which is how
   * a program learns how many arguments it was given. */
  return NULL;
}

int pas_binding_bound(void *v) { return pas_bound_to(v) != NULL; }

const char *pas_binding_name(void *v) {
  const char *name = pas_bound_to(v);
  return name ? name : "";
}

int pas_binding_namelen(void *v) {
  const char *name = pas_bound_to(v);
  return name ? (int)strlen(name) : 0;
}

/* ---------------------------------------------------------------- complex
 *
 * ISO/IEC 10206:1991 §6.7.6.2's transcendental functions over the complex
 * type. Each is two entry points, one per part, and each computes the whole
 * C99 result and returns half of it.
 *
 * That is deliberate, and the reason is an interface rather than a language
 * one: a `double complex` returned across this boundary would put the C ABI's
 * opinion about how a two-double aggregate travels into an interface whose
 * whole point is that neither backend has one. ADR-0030 settled the same
 * question the same way for a procedural parameter's code-and-link pair. The
 * cost is one redundant call per operation, in the six least common
 * operations in the language; the benefit is that the emitted IR names only
 * doubles.
 *
 * The two halves cannot disagree: each is the same libm call on the same
 * inputs, so both see the same rounding.
 *
 * §6.7.6.2's principal-value NOTE is C99's own convention — arg in (-pi, pi],
 * sqrt with non-negative real part — so these are direct calls rather than
 * re-derivations. */
#include <complex.h>

#define PAS_COMPLEX_FN(name, expr)                                            \
  double pas_c##name##_re(double re, double im) {                             \
    double complex z = re + im * I;                                           \
    (void)z;                                                                  \
    return creal(expr);                                                       \
  }                                                                           \
  double pas_c##name##_im(double re, double im) {                             \
    double complex z = re + im * I;                                           \
    (void)z;                                                                  \
    return cimag(expr);                                                       \
  }

PAS_COMPLEX_FN(sqrt, csqrt(z))
PAS_COMPLEX_FN(exp, cexp(z))
PAS_COMPLEX_FN(sin, csin(z))
PAS_COMPLEX_FN(cos, ccos(z))
PAS_COMPLEX_FN(arctan, catan(z))

/* §6.7.6.2: "For x of complex-type, it shall be an error if x = 0.0" — the one
 * error condition the complex functions carry, and the only one of the six
 * that is not total. */
double pas_cln_re(double re, double im) {
  if (re == 0.0 && im == 0.0)
    pas_runtime_error("ln: argument is zero");
  return creal(clog(re + im * I));
}
double pas_cln_im(double re, double im) {
  if (re == 0.0 && im == 0.0)
    pas_runtime_error("ln: argument is zero");
  return cimag(clog(re + im * I));
}

/* §6.8.3.2 table 3: `**` and `pow` take a complex left operand. The standard
 * defines both by the same words — "zero if x is zero, else 1.0 if y is zero,
 * else an approximation to exp(y*ln(x))" — and the two special cases are what
 * keep the definition total where `ln(0)` is not. The negative-base error the
 * *real* `**` carries has no counterpart here: a complex power of a negative
 * number is an ordinary value. */
static double complex pas_cpow_value(double re, double im, double y) {
  double complex x = re + im * I;
  if (re == 0.0 && im == 0.0)
    return 0.0;
  if (y == 0.0)
    return 1.0;
  return cpow(x, y);
}

double pas_cpow_re(double re, double im, double y) {
  return creal(pas_cpow_value(re, im, y));
}
double pas_cpow_im(double re, double im, double y) {
  return cimag(pas_cpow_value(re, im, y));
}
double pas_cpowi_re(double re, double im, int n) {
  return creal(pas_cpow_value(re, im, (double)n));
}
double pas_cpowi_im(double re, double im, int n) {
  return cimag(pas_cpow_value(re, im, (double)n));
}

/* ---------------------------------------------------------------- strings
 *
 * ISO/IEC 10206:1991 §6.4.3.3. A string *value* is a pointer and a length —
 * two scalars, never an aggregate — which is the shape ADR-0030 chose for a
 * procedural parameter and ADR-0049 for a complex, and for the same reason:
 * nothing then depends on how a two-word value is passed.
 *
 * `substr` and `trim` need no storage at all under that representation: they
 * are a pointer and a shorter length into the string they came from. Only
 * concatenation makes bytes that did not exist, and it takes them from the
 * arena below. A string value's life is one expression evaluation, so the
 * arena is a *stack*: everything a statement allocated is dead when that
 * statement finishes, and the generated code says so by restoring
 * `pas_str_at`.
 *
 * Nothing in this file can know when a value dies -- a pointer here is
 * indistinguishable from any other -- so the boundary has to come from the
 * compiler. ADR-0111 has the emission: `pas_str_at` is read once into an SSA
 * value at each function's entry and stored back at the end of every statement
 * that allocated, and `while` and `repeat` do the same for their conditions,
 * which are the one expression a statement evaluates more than once.
 *
 * It was a *ring* until ADR-0111, and wrapped in silence when one statement
 * asked for more than it holds: `a + a = b + b` over two 512K strings wrote
 * the second concatenation over the first, so the comparison had one address
 * twice and reported two values that differ everywhere as equal, with exit
 * status 0. The reasoning that stood here for why no program could reach it
 * -- a variable-string cannot be a value parameter, `write` consumes its
 * arguments in turn -- overlooked that a relational operator holds two string
 * values at once, which is `tests/extended/str_arena_overflow.pas`. Both ways
 * of exhausting the arena are now reported (ADR-0110). */

/* A variable-string variable is `{ i32, [capacity x i8] }` -- the current
 * length, then the characters. The compiler emits that layout (the `{ i32, [`
 * in CodeGen) and this reads it, and the two files cannot include one another,
 * which is the same bind `PAS_FILE_SIZE` and `fileSize` are in. So it gets the
 * same treatment they get: a name, and an assertion that the name is right.
 * It was a bare `4` at both use sites and nothing tied it to anything. */
#define PAS_STR_LENGTH_BYTES 4

_Static_assert(sizeof(int) == PAS_STR_LENGTH_BYTES,
               "the compiler writes a variable-string length as an LLVM i32, "
               "which this runtime reads through an int");

#define PAS_STR_ARENA (1 << 20)
static char pas_str_arena[PAS_STR_ARENA];

/* How much of the arena is in use, and the one datum the generated code shares
 * with this file rather than reaching through a function. It is named
 * `@pas_str_at = external global i32` in the emitted module, so the release at
 * a statement's end is a store and costs nothing in a program that never
 * concatenates -- where a call would have to be emitted in every prologue and
 * could not be optimised away. It is an `int` for the same reason a
 * variable-string's length is: the compiler writes both as an LLVM i32, and
 * the assertion above is what ties the two spellings together. */
int pas_str_at;

/* Both ways to run out are errors, and they are different mistakes: one value
 * too big for the arena however empty it is, against a statement holding more
 * live values at once than the arena has room for. */
static char *pas_str_temp(int n) {
  if (n < 0)
    n = 0;
  if (n > PAS_STR_ARENA)
    pas_runtime_error("a single string value is larger than the string arena");
  /* Neither term exceeds PAS_STR_ARENA, so the sum cannot overflow an int. */
  if (pas_str_at + n > PAS_STR_ARENA)
    pas_runtime_error("more string values are live at once than the string "
                      "arena holds");
  char *p = pas_str_arena + pas_str_at;
  pas_str_at += n;
  return p;
}

/* §6.4.3.3.1 gives the char-type "length 1 and capacity 1", so a char stands
 * wherever a string does. It has no address of its own in a register, and this
 * is where it gets one. */
char *pas_str_char(char c) {
  char *p = pas_str_temp(1);
  *p = c;
  return p;
}

/* ADR-0122: a string crossing to a foreign routine, as `const char *`.
 *
 * A Pascal string is a pointer and a length (ADR-0051) and a C string carries
 * its length in-band, so the boundary needs a copy with a NUL after it. The
 * copy goes in the arena above, which makes this a third arena producer and
 * means the emitter has to bump ADR-0111's counter where it writes the call --
 * a statement that took storage releases it, and this is storage.
 *
 * The arena is exactly the right lifetime: the value has to outlive the
 * argument list and must not outlive the statement, which is the rule the
 * arena already keeps. A `const char *` the callee stores away outlives both,
 * and nothing here can see that -- doc/sop.md §7.
 *
 * A NUL inside the value is an error rather than a truncation. C cannot
 * represent such a string at all, so there is no image to hand over; passing
 * the prefix would quietly rename a path or shorten a command, which is the
 * class of thing every other check here traps on. */
char *pas_str_cstr(const char *s, int len) {
  char *p;
  int i;
  if (len < 0) len = 0;
  for (i = 0; i < len; i++)
    if (s[i] == '\0')
      pas_runtime_error("a string crossing to a foreign routine contains a "
                        "NUL character");
  p = pas_str_temp(len + 1);
  memcpy(p, s, (size_t)len);
  p[len] = '\0';
  return p;
}

/* §6.8.3.6: "a + b shall denote a value of the canonical-string-type whose
 * length shall be equal to the sum of the length of a and the length of b."
 * The length is therefore known to the compiler and is not returned here. */
char *pas_str_concat(const char *a, int la, const char *b, int lb) {
  char *p;
  if (la < 0) la = 0;
  if (lb < 0) lb = 0;
  p = pas_str_temp(la + lb);
  memcpy(p, a, (size_t)la);
  memcpy(p + la, b, (size_t)lb);
  return p;
}

/* §6.8.3.5: the relational operators over string types. "For comparison of
 * values of compatible char-types or string-types, the relational-operators
 * effectively extend the shorter value with trailing spaces to the length of
 * the longer value." That is the ISO 7185 divergence that matters: there, the
 * lengths had to be equal. */
int pas_str_cmp_pad(const char *a, int la, const char *b, int lb) {
  int n = la > lb ? la : lb;
  for (int i = 0; i < n; i++) {
    unsigned char ca = i < la ? (unsigned char)a[i] : (unsigned char)' ';
    unsigned char cb = i < lb ? (unsigned char)b[i] : (unsigned char)' ';
    if (ca != cb)
      return ca < cb ? -1 : 1;
  }
  return 0;
}

/* §6.7.6.7's EQ/NE/LT/GT/LE/GE, which are *not* the operators: they compare
 * lengths as well as characters, so a proper prefix is strictly less than its
 * extension. The standard's NOTE 3 says so outright — "LT(a,b) could be false
 * and a<b true" — which is why the two comparisons are separate routines and
 * must not be unified. */
int pas_str_cmp_exact(const char *a, int la, const char *b, int lb) {
  int n = la < lb ? la : lb;
  for (int i = 0; i < n; i++) {
    unsigned char ca = (unsigned char)a[i], cb = (unsigned char)b[i];
    if (ca != cb)
      return ca < cb ? -1 : 1;
  }
  if (la == lb)
    return 0;
  return la < lb ? -1 : 1;
}

/* §6.7.6.7's `trim`: "if the value of sv[n] is not equal to the char-type
 * value space, the function shall yield the value of sv; otherwise ... the
 * least value p such that each component of sv[p..n] is the space." Trailing
 * spaces only, and an all-blank string yields the null-string. */
int pas_str_trimlen(const char *a, int la) {
  while (la > 0 && a[la - 1] == ' ')
    la--;
  return la;
}

/* §6.7.6.7's `index`: "the least i such that s1v[i..i+length(s2)-1] = s2, if
 * such an i exists; otherwise 0" — with the null-string yielding 1, and a
 * null s1 against a non-null s2 yielding 0. The window comparison is the
 * *operator*'s, which is space-padded; over equal lengths the two agree. */
int pas_str_index(const char *a, int la, const char *b, int lb) {
  if (lb == 0)
    return 1;
  if (la == 0)
    return 0;
  for (int i = 0; i + lb <= la; i++)
    if (memcmp(a + i, b, (size_t)lb) == 0)
      return i + 1;
  return 0;
}

/* §6.4.6 c): "it shall be an error if T1 and T2 are compatible, T1 is a
 * string-type or the char-type, and the length of the value of T2 is greater
 * than the capacity of T1." One message for every string assignment, because
 * it is one rule. */
static void pas_str_fits(int len, int cap) {
  if (len > cap) {
    char msg[128];
    snprintf(msg, sizeof msg,
             "a string of length %d does not fit a capacity of %d", len, cap);
    pas_runtime_error(msg);
  }
}

/* §6.4.6: a canonical value assigned to a *fixed*-string-type is "the
 * components of the canonical-string-type value ... followed by zero or more
 * spaces", so a short value is padded and the length is always the capacity. */
void pas_str_store_fixed(char *dst, int cap, const char *src, int len) {
  pas_str_fits(len, cap);
  memmove(dst, src, (size_t)len);
  memset(dst + len, ' ', (size_t)(cap - len));
}

/* ...and to a variable-string-type it is the components and nothing else: the
 * length becomes the value's, which is the whole difference between the two
 * string kinds. */
void pas_str_store_var(void *dst, int cap, const char *src, int len) {
  pas_str_fits(len, cap);
  *(int *)dst = len;
  memmove((char *)dst + PAS_STR_LENGTH_BYTES, src, (size_t)len);
}

/* ADR-0123: a C string arriving as an optional, which is the only direction a
 * foreign pointer travels in.
 *
 * `dst` is the *value* half of the optional -- a variable-string of capacity
 * `cap` -- and the answer is the flag the caller stores in the other half. So
 * the layout stays entirely the compiler's: this routine knows what a string
 * is and nothing about what an optional is.
 *
 * NULL is absence and not an error. That is the whole reason ADR-0122 refused
 * a returned pointer and this record admits one: `getenv` of a name that is
 * not set answers NULL in the ordinary course of things, and a language with
 * no optional type would have had to trap on it or lie about it.
 *
 * A string too long for the capacity *is* an error, and pas_str_store_var
 * reports it in the words 6.4.6 uses for an over-long assignment -- the same
 * words, because it is the same rule and the value merely came from further
 * away. */
int pas_cstr_take(void *dst, int cap, const char *s) {
  if (s == NULL)
    return 0;
  pas_str_store_var(dst, cap, s, (int)strlen(s));
  return 1;
}

/* §6.4.6 again: a char is a string of capacity 1. A null-string padded to that
 * capacity is a space, which is the case worth spelling out. */
void pas_str_store_char(char *dst, const char *src, int len) {
  pas_str_fits(len, 1);
  *dst = len == 1 ? src[0] : ' ';
}

/* A string value is written by `pas_write_str`, which ISO 7185 already had
 * for a `packed array [1..n] of char` — a string value is a pointer and a
 * length, which is exactly what that call takes, so the two string kinds and
 * the char share one path. */

/* §6.5.6 and §6.7.6.7's substr share their error conditions: an index below 1,
 * an index past the length, and a first index greater than the second. `substr`
 * states them as `i <= 0`, `j < 0` and `i+j-1 > length`, which is the same
 * three once j is a count rather than an end. */
/* ISO/IEC 10206:1991 6.5.6 and 6.8.6.5: `s[i..j]`. The conditions are "less
 * than 1", "greater than the length", and "the first greater than the second"
 * — and that last one is where this parts company with pas_str_slice_check
 * above. 6.7.6.7 lets `substr(s, i, 0)` yield the null-string, so a count of
 * zero is legal there; `s[3..2]` has i > j and is an error here. The two
 * conditions differ at exactly the empty case, which is why they cannot be one
 * function however alike they look. */
void pas_str_substr_check(int lo, int hi, int len) {
  if (lo < 1 || hi > len || lo > hi) {
    char msg[160];
    snprintf(msg, sizeof msg,
             "substring: [%d..%d] is not within a string of length %d", lo, hi,
             len);
    pas_runtime_error(msg);
  }
}

/* ADR-0125: `a[i..j]`, after the indices have been normalised to the base's
 * own 1..n. Its own routine rather than pas_str_substr_check above, for two
 * reasons that are both about what it says: a slice is not a string, and an
 * *empty* slice is admissible where an empty substring range is not --
 * §6.7.6.7 already lets `substr(s, i, 0)` yield the null-string, and a loop
 * that consumes a slice down to nothing should not have to special-case its
 * last step. So `hi = lo - 1` is the empty slice and `hi < lo - 1` is an
 * error. */
void pas_slice_check(int lo, int hi, int len) {
  if (lo < 1 || hi > len || hi < lo - 1) {
    char msg[160];
    snprintf(msg, sizeof msg,
             "slice: [%d..%d] is not within a sequence of %d components", lo,
             hi, len);
    pas_runtime_error(msg);
  }
}

void pas_str_slice_check(int at, int count, int len) {
  if (at <= 0 || count < 0 || at + count - 1 > len) {
    char msg[160];
    snprintf(msg, sizeof msg,
             "substr: %d characters from position %d is outside a string of "
             "length %d", count, at, len);
    pas_runtime_error(msg);
  }
}

/* §6.10.1 e) and f): reading a string does *not* skip leading blanks, never
 * crosses an end-of-line, and takes at most the capacity. A fixed target is
 * then padded with spaces and a variable one gets exactly what was read. */
void pas_read_str(void *v, void *dst, int cap, int isvar) {
  struct pas_file *f = v;
  char *out = isvar ? (char *)dst + PAS_STR_LENGTH_BYTES : (char *)dst;
  int n = 0;
  while (n < cap) {
    pas_fill(f);
    if (f->ateof || f->lookahead == '\n')
      break;
    out[n++] = f->ch;
    f->have = 0;
  }
  if (isvar)
    *(int *)dst = n;
  else
    memset(out + n, ' ', (size_t)(cap - n));
}

/* ISO/IEC 10206:1991 §6.7.5.5 defines readstr and writestr *as* a sequence of
 * ordinary file operations on "an auxiliary variable that the program does not
 * otherwise contain, which possesses the required type text". These four
 * functions are that auxiliary variable, and nothing else about either
 * statement is new: the compiler emits the same pas_read_* and pas_write_*
 * calls it emits for a text file, with the handle these hand back.
 *
 * It is heap-allocated rather than a static, because a variable-access or a
 * write-parameter may call a function that itself contains a readstr; and it
 * is *not* on the open-file list, because §6.7.5.5 makes it a variable the
 * program does not contain, so it is none of the business of the block exits
 * and non-local gotos that list serves (ADR-0032). */
static struct pas_file *pas_str_file(void) {
  struct pas_file *f = calloc(1, sizeof *f);
  if (!f)
    pas_runtime_error("out of memory for a string transfer");
  f->lookahead = EOF;
  f->istext = 1;
  f->compsize = 1;
  f->ch = ' ';
  f->buf = &f->ch;
  f->name = "a string";
  return f;
}

/* `rewrite(f); writeln(f, e); reset(f)` — the line marker writeln appends is
 * the trailing newline here, and it is what keeps eof false while the values
 * are being read. The characters are *copied*, so that a readstr may read
 * into the very variable it reads from. */
void *pas_str_read_begin(const char *chars, int len) {
  struct pas_file *f = pas_str_file();
  f->membuf = malloc((size_t)len + 1);
  if (!f->membuf)
    pas_runtime_error("out of memory for a string transfer");
  memcpy(f->membuf, chars, (size_t)len);
  f->membuf[len] = '\n';
  f->fp = fmemopen(f->membuf, (size_t)len + 1, "r");
  if (!f->fp)
    pas_runtime_error("cannot read from a string");
  f->mode = PAS_READING;
  return f;
}

/* §6.7.5.5: "It shall be an error if the equivalent of eof(f) is true upon
 * completion." The line marker is still there when every value had a
 * representation to read, so eof means the reads ran off the end. */
void pas_str_read_end(void *v) {
  struct pas_file *f = v;
  if (pas_eof(f))
    pas_runtime_error("readstr: the string ended before every value was read");
  fclose(f->fp);
  free(f->membuf);
  free(f);
}

void *pas_str_write_begin(void) {
  struct pas_file *f = pas_str_file();
  f->fp = open_memstream(&f->membuf, &f->memlen);
  if (!f->fp)
    pas_runtime_error("cannot write to a string");
  f->mode = PAS_WRITING;
  return f;
}

/* The `reset(f); read(f, ss)` half: what was written is a string value, which
 * is a pointer and a length (ADR-0051), so the assignment to the
 * string-variable is the ordinary string store and needs nothing of its own.
 * §6.7.5.5's "error if the equivalent of eoln(f) is false upon completion" is
 * then that store's capacity check, because eoln is false exactly when more
 * was written than the read could take. */
int pas_str_write_len(void *v) {
  struct pas_file *f = v;
  fflush(f->fp);
  if (f->memlen > 2147483647u)
    pas_runtime_error("writestr: too much was written to a string");
  return (int)f->memlen;
}

const char *pas_str_write_ptr(void *v) {
  struct pas_file *f = v;
  fflush(f->fp);
  return f->membuf ? f->membuf : "";
}

void pas_str_write_end(void *v) {
  struct pas_file *f = v;
  fclose(f->fp);
  free(f->membuf);
  free(f);
}

/* ------------------------------------------------------------------- time
 *
 * ISO/IEC 10206:1991 §6.7.5.8's `GetTimeStamp` and §6.7.6.9's `date` and
 * `time`. What crosses this boundary is numbers and characters, never the
 * shape of a TimeStamp: the compiler holds the record's layout and does the
 * eight stores itself, so `pas_gettimestamp` samples the clock and
 * `pas_timestamp_field` hands the parts back one at a time.
 *
 * Two calls rather than one filling a caller's buffer, because the Pascal
 * backend emits sequentially and cannot put an `alloca` in the entry block
 * after the fact (ADR-0043) — scratch storage for the sample would grow the
 * stack once per `GetTimeStamp` in a loop. A static costs nothing and there is
 * no second thread to race it. */

static int pas_stamp[8];

/* §6.7.5.8: the value attributed has DateValid true and the current date, or
 * DateValid false and 'January 1, 1'; and TimeValid true and the current time,
 * or TimeValid false and midnight.
 *
 * "Current" is implementation-defined (D.36 and D.37 both say so), and this
 * implementation defines it as **the instant named by SOURCE_DATE_EPOCH when
 * that variable holds one, and the system clock otherwise**. That is the
 * reproducible-builds convention, and it is not a testing hook bolted on: it
 * is the only way anything can check that these eight fields are the *right*
 * eight numbers. A program cannot know what day it is except by asking this
 * same function, so without a clock somebody else chooses, an off-by-one in
 * any field is invisible — `tm_mon` written unadjusted names a different real
 * month eleven times out of twelve, and every oracle here agrees with it.
 *
 * A fixed instant is read as **UTC**, because the point of fixing it is that
 * the answer not vary, and local time would make it vary with the machine's
 * zone. A value that does not parse is ignored rather than reported, so the
 * variable can only ever replace the clock, never break it.
 *
 * The two flags are separate in the standard and separate here: neither the
 * clock failing nor an instant the calendar cannot express supplies a date or
 * a time, so both go false together. Such a platform therefore reports the
 * fallbacks the clause names rather than a wrong date, which is the whole
 * point of having them -- and an unconvertible SOURCE_DATE_EPOCH is the one
 * way a program can reach that arm on a machine whose clock works, which is
 * what makes it something a test can check. */
void pas_gettimestamp(void) {
  const char *fixed = getenv("SOURCE_DATE_EPOCH");
  struct tm *t = NULL;
  /* Whether the variable named an instant at all -- which is what decides
   * where a failure goes, below. */
  int named = 0;
  time_t now;
  if (fixed && *fixed) {
    char *end;
    long long v = strtoll(fixed, &end, 10);
    /* strtoll answers 0 for a word it cannot read, so "did it consume the
     * whole word" is the question, not "what did it return": without this the
     * variable set to anything at all would date the program 1970-01-01. An
     * empty setting parses as 0 with nothing left over, which is why it is
     * refused by the test above rather than by this one. */
    if (*end == '\0') {
      named = 1;
      now = (time_t)v;
      t = gmtime(&now);
    }
  }
  /* The clock is consulted only when no instant was named. A named one that
   * the calendar cannot express -- a count of seconds whose year does not fit
   * the representation -- falls to the arm below instead, because answering
   * with the wall clock would make the output of a program vary from run to
   * run while the variable that exists to fix it was set. That is the same
   * kind of wrong answer as 1970: one nothing reports. */
  if (!t && !named) {
    now = time(NULL);
    if (now != (time_t)-1)
      t = localtime(&now);
  }
  if (!t) {
    pas_stamp[0] = 0; /* DateValid */
    pas_stamp[1] = 0; /* TimeValid */
    pas_stamp[2] = 1; /* year   -- 'January 1, 1' */
    pas_stamp[3] = 1; /* month */
    pas_stamp[4] = 1; /* day */
    pas_stamp[5] = 0; /* hour   -- midnight */
    pas_stamp[6] = 0; /* minute */
    pas_stamp[7] = 0; /* second */
    return;
  }
  pas_stamp[0] = 1;
  pas_stamp[1] = 1;
  pas_stamp[2] = t->tm_year + 1900;
  pas_stamp[3] = t->tm_mon + 1;
  pas_stamp[4] = t->tm_mday;
  pas_stamp[5] = t->tm_hour;
  pas_stamp[6] = t->tm_min;
  /* A leap second gives tm_sec 60, which is not a value of the field's
   * subrange 0..59 — so it is clamped here rather than trapping in a program
   * that did nothing wrong. §6.4.3.4 NOTE 5 lets a processor report leap
   * seconds in a field of its own; this one does not have such a field. */
  pas_stamp[7] = t->tm_sec > 59 ? 59 : t->tm_sec;
}

int pas_timestamp_field(int k) {
  if (k < 0 || k > 7)
    pas_runtime_error("GetTimeStamp: no such field");
  return pas_stamp[k];
}

/* §6.7.6.9: "It shall be an error if the fields day, month, and year of t do
 * not represent a valid calendar date." month and day are already inside
 * 1..12 and 1..31 -- their subranges saw to that at every store -- so what is
 * left is the length of the month, February in a leap year, and a year this
 * representation cannot write.
 *
 * The Gregorian rule is the standard's own word ("the current date under the
 * Gregorian calendar"), and the year range is this implementation's: the
 * result has one implementation-defined *length*, four digits of year is what
 * that length allows, and a year outside 1..9999 therefore has no
 * representation here. The calendar has no year 0 either way. */
static int pas_days_in_month(int y, int m) {
  static const int len[13] = {0,  31, 28, 31, 30, 31, 30,
                              31, 31, 30, 31, 30, 31};
  if (m == 2 && (y % 4 == 0 && (y % 100 != 0 || y % 400 == 0)))
    return 29;
  return len[m];
}

char *pas_date(int y, int m, int d) {
  char *p;
  if (y < 1 || y > 9999)
    pas_runtime_error("date: the year is not one this implementation can "
                      "write (1 to 9999)");
  if (m < 1 || m > 12 || d < 1 || d > pas_days_in_month(y, m))
    pas_runtime_error("date: the day, month and year are not a valid "
                      "calendar date");
  p = pas_str_temp(10);
  /* Written by hand rather than with snprintf, which would need eleven bytes
   * for its terminator where a string value is exactly its length. */
  p[0] = (char)('0' + y / 1000);
  p[1] = (char)('0' + y / 100 % 10);
  p[2] = (char)('0' + y / 10 % 10);
  p[3] = (char)('0' + y % 10);
  p[4] = '-';
  p[5] = (char)('0' + m / 10);
  p[6] = (char)('0' + m % 10);
  p[7] = '-';
  p[8] = (char)('0' + d / 10);
  p[9] = (char)('0' + d % 10);
  return p;
}

/* §6.7.6.9 gives `time` no error condition, and it needs none: hour, minute
 * and second are 0..23 and 0..59, so every value the type admits has a
 * representation. The asymmetry with `date` is the standard's. */
char *pas_time(int h, int m, int s) {
  char *p = pas_str_temp(8);
  p[0] = (char)('0' + h / 10);
  p[1] = (char)('0' + h % 10);
  p[2] = ':';
  p[3] = (char)('0' + m / 10);
  p[4] = (char)('0' + m % 10);
  p[5] = ':';
  p[6] = (char)('0' + s / 10);
  p[7] = (char)('0' + s % 10);
  return p;
}

/* ---------------------------------------------------------------------- */
/* The runtime's second surface: what a Pascal *program* may bind by name.
 *
 * Everything above is called by code the compiler emits, and `pas_` is
 * reserved for exactly that reason -- ReservedForeignName refuses the whole
 * prefix, because LLVM will not take a second declaration of a global the
 * emitted module already declares. A routine the emitter never names is not
 * that hazard, so it gets `pasx_` and a program may write
 * `external 'pasx_...'`.
 *
 * The split is what keeps ReservedForeignName a mirror of the **emitter**
 * rather than of the archive. Do not add a `pasx_` routine that the compiler
 * also emits calls to, and do not rename a `pas_` one into this space to make
 * it bindable: the reason `pas_atan` and `pas_hypot` exist is that a program
 * should be able to have the *libc* spellings, which is the opposite move.
 */

/* ADR-0130 recorded, and ADR-0122 before it, that a failure in a binding
 * module is `errIO` and nothing finer, because `errno` is unreachable: C
 * specifies it as a **macro**, and glibc spells it `*__errno_location()`, so
 * it is a returned pointer even before it is a macro. No foreign-function
 * interface can bind a macro -- not this one and not a better one -- which is
 * what puts it here rather than behind a language decision.
 *
 * The value is only meaningful immediately after a call that reported a
 * failure; nothing clears it on success, and any intervening library call may
 * set it. That is C's contract and this does not improve on it.
 */
int pasx_errno(void) { return errno; }
