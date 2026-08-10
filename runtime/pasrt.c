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
#include <math.h>
#include <setjmp.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "pasrt.h"

void pas_runtime_error(const char *msg) {
  fflush(stdout);
  fprintf(stderr, "runtime error: %s\n", msg);
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

enum { PAS_CLOSED = 0, PAS_READING = 1, PAS_WRITING = 2 };

struct pas_file {
  FILE *fp;
  int mode;
  int binding;   /* one of the PAS_BIND_* constants */
  int arg;       /* which command-line argument, when binding is PAS_BIND_ARG */
  int lookahead; /* text: the raw character, or EOF; only when `have` */
  int have;      /* the buffer variable holds the current component */
  int istext;    /* a `text`, with line structure; not a `file of char` */
  int compsize;  /* the size of one component in bytes; 1 for a text */
  int ateof;     /* non-text: the fetch that filled `have` found no component */
  char ch;       /* the buffer variable of a text file */
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
  if (f->mode != mode)
    pas_error2(op, f->mode == PAS_CLOSED ? " a file that is not open"
                                         : " a file open in the other mode");
}

/* The external file a variable stands for, or a diagnostic if the program was
 * not given one. */
static const char *pas_external(struct pas_file *f) {
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
                   int compsize, int istext) {
  struct pas_file *f = v;
  f->fp = NULL;
  f->mode = PAS_CLOSED;
  f->binding = binding;
  f->arg = arg;
  f->lookahead = EOF;
  f->have = 0;
  f->istext = istext;
  f->compsize = compsize > 0 ? compsize : 1;
  f->ateof = 0;
  f->ch = ' ';
  f->name = name;
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
      return; /* the process owns the standard files, and `ch` is not ours */
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
  f->have = 0;
  f->lookahead = EOF;
  f->ateof = 0;
  f->ch = ' ';
  switch (f->binding) {
  case PAS_BIND_INPUT:
    f->fp = stdin;
    break;
  case PAS_BIND_OUTPUT:
    pas_runtime_error("reset applied to the standard output");
    break;
  case PAS_BIND_ARG: {
    const char *name = pas_external(f);
    if (f->fp)
      fclose(f->fp);
    /* The component of a `file of T` is T's machine representation, so the
     * stream must not be translated on a platform that would. */
    f->fp = fopen(name, f->istext ? "r" : "rb");
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
    f->fp = fopen(name, f->istext ? "w" : "wb");
    if (!f->fp)
      pas_error2("cannot open for writing: ", name);
    break;
  }
  default:
    if (f->fp)
      fclose(f->fp);
    f->fp = tmpfile();
    if (!f->fp)
      pas_runtime_error("cannot create a temporary file");
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
  f->lookahead = getc(f->fp);
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
  if (f->mode == PAS_READING) {
    pas_fill(f);
    if (f->ateof)
      pas_runtime_error("the buffer variable is undefined at end of file");
  } else {
    pas_check_open(f, PAS_WRITING, "using the buffer variable of");
  }
  return f->buf;
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

double pas_read_real(void *v) {
  struct pas_file *f = v;
  char buf[64];
  size_t n = 0;
  int digits = 0;

  pas_skip_blanks(f);
  if (f->lookahead == '+' || f->lookahead == '-') {
    buf[n++] = (char)f->lookahead;
    f->have = 0;
    pas_fill(f);
  }
  while (f->lookahead >= '0' && f->lookahead <= '9' && n + 1 < sizeof buf) {
    buf[n++] = (char)f->lookahead;
    ++digits;
    f->have = 0;
    pas_fill(f);
  }
  if (f->lookahead == '.' && n + 1 < sizeof buf) {
    buf[n++] = '.';
    f->have = 0;
    pas_fill(f);
    while (f->lookahead >= '0' && f->lookahead <= '9' && n + 1 < sizeof buf) {
      buf[n++] = (char)f->lookahead;
      ++digits;
      f->have = 0;
      pas_fill(f);
    }
  }
  if ((f->lookahead == 'e' || f->lookahead == 'E') && digits &&
      n + 1 < sizeof buf) {
    buf[n++] = 'e';
    f->have = 0;
    pas_fill(f);
    if ((f->lookahead == '+' || f->lookahead == '-') && n + 1 < sizeof buf) {
      buf[n++] = (char)f->lookahead;
      f->have = 0;
      pas_fill(f);
    }
    while (f->lookahead >= '0' && f->lookahead <= '9' && n + 1 < sizeof buf) {
      buf[n++] = (char)f->lookahead;
      f->have = 0;
      pas_fill(f);
    }
  }
  if (!digits)
    pas_runtime_error("expected a number in the input");
  buf[n] = '\0';
  return strtod(buf, NULL);
}

/* ------------------------------------------------------------------ output */

static FILE *pas_out(void *v) {
  struct pas_file *f = v;
  pas_check_open(f, PAS_WRITING, "writing to");
  return f->fp;
}

void pas_write_int(void *v, long long val, int width) {
  FILE *o = pas_out(v);
  if (width < 0) fprintf(o, "%lld", val);
  else fprintf(o, "%*lld", width, val);
}

void pas_write_real(void *v, double val, int width, int prec) {
  FILE *o = pas_out(v);
  if (prec >= 0) {
    /* fixed-point form: write(x:w:p) */
    if (width < 0) fprintf(o, "%.*f", prec, val);
    else fprintf(o, "%*.*f", width, prec, val);
  } else if (width < 0) {
    /* default form is floating (scientific), with a slot for the sign */
    fprintf(o, "% .12E", val);
  } else {
    fprintf(o, "%*.6E", width, val);
  }
}

void pas_write_bool(void *v, int val, int width) {
  FILE *o = pas_out(v);
  const char *s = val ? "TRUE" : "FALSE";
  if (width < 0) fputs(s, o);
  else fprintf(o, "%*s", width, s);
}

void pas_write_char(void *v, char c, int width) {
  FILE *o = pas_out(v);
  if (width < 0) putc(c, o);
  else fprintf(o, "%*c", width, c);
}

void pas_write_str(void *v, const char *s, int len, int width) {
  FILE *o = pas_out(v);
  if (width <= len) fwrite(s, 1, (size_t)len, o);
  else fprintf(o, "%*.*s", width, len, s);
}

void pas_writeln(void *v) { putc('\n', pas_out(v)); }

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

void pas_halt(int code) {
  fflush(stdout);
  exit(code);
}
