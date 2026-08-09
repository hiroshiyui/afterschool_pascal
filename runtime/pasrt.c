/* Afterschool Pascal runtime library.
 *
 * Everything the generated code cannot express directly in LLVM IR lives here:
 * formatted output, and the handful of runtime checks the compiler emits.
 *
 * Field-width conventions (see README):
 *   width < 0  means "no width given"
 *   prec  < 0  means "no precision given"
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

void pas_write_int(long long v, int width) {
  if (width < 0) printf("%lld", v);
  else printf("%*lld", width, v);
}

void pas_write_real(double v, int width, int prec) {
  if (prec >= 0) {
    /* fixed-point form: write(x:w:p) */
    if (width < 0) printf("%.*f", prec, v);
    else printf("%*.*f", width, prec, v);
  } else if (width < 0) {
    /* default form is floating (scientific), with a slot for the sign */
    printf("% .12E", v);
  } else {
    printf("%*.6E", width, v);
  }
}

void pas_write_bool(int v, int width) {
  const char *s = v ? "TRUE" : "FALSE";
  if (width < 0) fputs(s, stdout);
  else printf("%*s", width, s);
}

void pas_write_char(char c, int width) {
  if (width < 0) putchar(c);
  else printf("%*c", width, c);
}

void pas_write_str(const char *s, int len, int width) {
  if (width < 0) fwrite(s, 1, (size_t)len, stdout);
  else if (width <= len) fwrite(s, 1, (size_t)len, stdout);
  else printf("%*.*s", width, len, s);
}

void pas_writeln(void) { putchar('\n'); }

void pas_runtime_error(const char *msg) {
  fflush(stdout);
  fprintf(stderr, "runtime error: %s\n", msg);
  exit(1);
}

void pas_halt(int code) {
  fflush(stdout);
  exit(code);
}
