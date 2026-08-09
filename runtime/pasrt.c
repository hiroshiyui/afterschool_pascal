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

/* ------------------------------------------------------------------- files */

/* ISO 7185 §6.4.3.5 gives every file variable a buffer variable `f^` and
 * defines `get` and `put` on it; `read` and `write` are *derived* from those.
 * This runtime keeps that structure rather than flattening it: the primitives
 * below are the real ones, and everything else is written in terms of them.
 *
 * That is not pedantry. The buffer variable is one character of lookahead, and
 * a lexer — the first thing the self-hosted compiler needs — is exactly the
 * program that wants to inspect the next character without consuming it. */

enum { PAS_CLOSED = 0, PAS_READING = 1, PAS_WRITING = 2 };

struct pas_file {
  FILE *fp;
  int mode;
  int binding;   /* one of the PAS_BIND_* constants */
  int arg;       /* which command-line argument, when binding is PAS_BIND_ARG */
  int lookahead; /* the raw character, or EOF; meaningful only when `have` */
  int have;      /* the lookahead has been fetched */
  char ch;       /* the buffer variable f^, as the program sees it */
  const char *name; /* what to call this file in a diagnostic */
};

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

void pas_file_init(void *v, int binding, int arg, const char *name) {
  struct pas_file *f = v;
  f->fp = NULL;
  f->mode = PAS_CLOSED;
  f->binding = binding;
  f->arg = arg;
  f->lookahead = EOF;
  f->have = 0;
  f->ch = ' ';
  f->name = name;
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
  if (!f->fp)
    return;
  if (f->binding == PAS_BIND_INPUT || f->binding == PAS_BIND_OUTPUT) {
    fflush(f->fp);
    return;
  }
  fclose(f->fp);
  f->fp = NULL;
  f->mode = PAS_CLOSED;
}

void pas_reset(void *v) {
  struct pas_file *f = v;
  f->have = 0;
  f->lookahead = EOF;
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
    f->fp = fopen(name, "r");
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
    f->fp = fopen(name, "w");
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
  f->lookahead = getc(f->fp);
  f->have = 1;
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
  return f->lookahead == EOF;
}

int pas_eoln(void *v) {
  struct pas_file *f = v;
  pas_fill(f);
  if (f->lookahead == EOF)
    pas_runtime_error("eoln at the end of the file");
  return f->lookahead == '\n';
}

/* The address of the buffer variable f^. For a file being read the lookahead
 * has to be there first; for one being written the program assigns to it and
 * then calls put. */
char *pas_buffer(void *v) {
  struct pas_file *f = v;
  if (f->mode == PAS_READING) {
    pas_fill(f);
    if (f->lookahead == EOF)
      pas_runtime_error("the buffer variable is undefined at end of file");
  } else {
    pas_check_open(f, PAS_WRITING, "using the buffer variable of");
  }
  return &f->ch;
}

void pas_get(void *v) {
  struct pas_file *f = v;
  pas_fill(f);
  if (f->lookahead == EOF)
    pas_runtime_error("get past the end of the file");
  f->have = 0; /* the next fill fetches the following character */
}

void pas_put(void *v) {
  struct pas_file *f = v;
  pas_check_open(f, PAS_WRITING, "writing to");
  putc(f->ch, f->fp);
}

/* --- the derived read operations, in terms of the primitives above -------- */

char pas_read_char(void *v) {
  struct pas_file *f = v;
  char c = *pas_buffer(v); /* c := f^ */
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
