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

/* runtime/pasrt_unicode.c against Unicode's own answers.
 *
 * This is the oracle ADR-0189 chose the grapheme model partly in order to
 * have: NormalizationTest.txt and GraphemeBreakTest.txt are published with the
 * database, state an input and the answer, and were written by people with no
 * interest in this compiler. Every other check in this repository compares
 * this compiler against a reading taken here.
 *
 * Two of the three sections have such a file behind them. The third does not
 * and says so: UTF-8 well-formedness has no conformance file, so the ill-formed
 * cases below are written out from The Unicode Standard's Table 3-7 -- an
 * overlong encoding, a surrogate, a truncation and a code point above the
 * range. That table is short and unambiguous, which is why writing it out is
 * defensible where writing out a normalisation would not be.
 *
 *     unicode_conf <ucd-directory>
 *
 * Answers 0 when everything agrees, 1 on any disagreement, and 2 when a file
 * is missing -- which the harness turns into a skip rather than a failure. */

#include "pasrt_unicode.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MAXCP 0x110000
#define MAXSEQ 64
#define LINE 8192

static int failures = 0;
static int shown = 0;

/* Lines that survived comment-stripping and were then not used.
 *
 * This is the corpus-size check `difftest` needs for the same reason: a parser
 * that quietly stopped recognising the format would compare fewer cases and
 * report success, and "everything agreed" and "nothing was compared" print the
 * same way. Every data line in both files is required to yield a case. */
static int unused = 0;

static void fail(const char *what, const char *line) {
  failures++;
  if (shown < 10) {
    shown++;
    fprintf(stderr, "unicode-conformance: %s\n  %s\n", what, line);
  }
}

static FILE *must_open(const char *dir, const char *name) {
  char path[4096];
  FILE *f;
  snprintf(path, sizeof path, "%s/%s", dir, name);
  f = fopen(path, "r");
  if (f == NULL) {
    fprintf(stderr, "unicode-conformance: no %s\n", path);
    exit(2);
  }
  return f;
}

/* --- little UTF-8 helpers, independent of the code under test ------------ */

/* Deliberately not pasrt_unicode.c's encoder. A harness that shared the
 * encoder with the thing it tests would agree with it about a wrong encoding,
 * which is the closed loop doc/sop.md warns about. */
static long long put(char *dst, long long at, unsigned int cp) {
  if (cp < 0x80u) {
    dst[at++] = (char)cp;
  } else if (cp < 0x800u) {
    dst[at++] = (char)(0xC0u | (cp >> 6));
    dst[at++] = (char)(0x80u | (cp & 0x3Fu));
  } else if (cp < 0x10000u) {
    dst[at++] = (char)(0xE0u | (cp >> 12));
    dst[at++] = (char)(0x80u | ((cp >> 6) & 0x3Fu));
    dst[at++] = (char)(0x80u | (cp & 0x3Fu));
  } else {
    dst[at++] = (char)(0xF0u | (cp >> 18));
    dst[at++] = (char)(0x80u | ((cp >> 12) & 0x3Fu));
    dst[at++] = (char)(0x80u | ((cp >> 6) & 0x3Fu));
    dst[at++] = (char)(0x80u | (cp & 0x3Fu));
  }
  return at;
}

static long long encode(const unsigned int *cps, int n, char *dst) {
  long long at = 0;
  for (int i = 0; i < n; i++)
    at = put(dst, at, cps[i]);
  return at;
}

/* Hex code points out of a field like "0044 0307". */
static int scan_field(const char *s, unsigned int *out) {
  int n = 0;
  while (*s != '\0' && n < MAXSEQ) {
    char *end;
    unsigned long v;
    while (*s == ' ')
      s++;
    if (*s == '\0')
      break;
    v = strtoul(s, &end, 16);
    if (end == s)
      break;
    out[n++] = (unsigned int)v;
    s = end;
  }
  return n;
}

/* --- normalisation -------------------------------------------------------- */

/* c2 == toNFC(c1) == toNFC(c2) == toNFC(c3), and c4 == toNFC(c4) == toNFC(c5). */
static void check_nfc(const char *src, long long srclen, const char *want,
                      long long wantlen, const char *line) {
  char got[MAXSEQ * 4 * 4];
  long long n = pas_text_nfc(src, srclen, got, (long long)sizeof got);
  if (n < 0) {
    fail("pas_text_nfc reported a status where a length was due", line);
    return;
  }
  if (n != wantlen || memcmp(got, want, (size_t)n) != 0)
    fail("NFC differs from NormalizationTest.txt", line);
}

static int normalization(const char *dir, unsigned char *listed) {
  FILE *f = must_open(dir, "NormalizationTest.txt");
  char line[LINE];
  int cases = 0;

  while (fgets(line, sizeof line, f) != NULL) {
    unsigned int cps[5][MAXSEQ];
    int len[5];
    char enc[5][MAXSEQ * 4];
    long long elen[5];
    char *hash = strchr(line, '#');
    char *field = line;
    int i;

    if (hash != NULL)
      *hash = '\0';
    if (line[0] == '@' || line[0] == '\0' || line[0] == '\n')
      continue;

    for (i = 0; i < 5; i++) {
      char *semi = strchr(field, ';');
      if (semi == NULL)
        break;
      *semi = '\0';
      len[i] = scan_field(field, cps[i]);
      elen[i] = encode(cps[i], len[i], enc[i]);
      field = semi + 1;
    }
    if (i < 5) {
      unused++;
      continue;
    }

    /* Part 1 is one code point per line, and invariant 2 is about every code
     * point it does *not* list. */
    if (len[0] == 1)
      listed[cps[0][0]] = 1;

    check_nfc(enc[0], elen[0], enc[1], elen[1], line);
    check_nfc(enc[1], elen[1], enc[1], elen[1], line);
    check_nfc(enc[2], elen[2], enc[1], elen[1], line);
    check_nfc(enc[3], elen[3], enc[3], elen[3], line);
    check_nfc(enc[4], elen[4], enc[3], elen[3], line);
    cases++;
  }
  fclose(f);
  return cases;
}

/* Invariant 2: every code point not listed in Part 1 is its own NFC. This is
 * the half that sweeps rather than samples -- a million and more code points,
 * where the file itself has twenty thousand lines. */
static int unlisted(const unsigned char *listed) {
  char src[4], got[8];
  int checked = 0;
  for (unsigned int cp = 0; cp < MAXCP; cp++) {
    long long n, k;
    if (cp >= 0xD800u && cp <= 0xDFFFu) /* not a scalar value */
      continue;
    if (listed[cp])
      continue;
    k = put(src, 0, cp);
    n = pas_text_nfc(src, k, got, (long long)sizeof got);
    if (n != k || memcmp(got, src, (size_t)k) != 0) {
      char what[64];
      snprintf(what, sizeof what, "U+%04X is not its own NFC", cp);
      fail(what, "NormalizationTest.txt invariant 2");
    }
    checked++;
  }
  return checked;
}

/* --- segmentation --------------------------------------------------------- */

/* A line is `÷ 0020 × 0308 ÷`, where ÷ is a boundary and × is not. Both are
 * two bytes of UTF-8 whose lead is 0xC3, and nothing else on the line is
 * non-ASCII once the comment is cut, so the pair of bytes distinguishes them.
 *
 * The file gives boundaries by *element* index; what pas_text_next answers is
 * a byte offset, so the two are converted through a prefix table rather than
 * compared as they stand. */
static int segmentation(const char *dir) {
  FILE *f = must_open(dir, "auxiliary/GraphemeBreakTest.txt");
  char line[LINE];
  int cases = 0;

  while (fgets(line, sizeof line, f) != NULL) {
    unsigned int cps[MAXSEQ];
    int bound[MAXSEQ + 1];
    long long off[MAXSEQ + 1];
    char text[MAXSEQ * 4];
    int n = 0, nb = 0, w;
    long long total, i;
    char *hash = strchr(line, '#');
    const unsigned char *p;

    if (hash != NULL)
      *hash = '\0';

    for (p = (const unsigned char *)line; *p != '\0'; p++) {
      if (p[0] == 0xC3u && p[1] == 0xB7u) { /* U+00F7 DIVISION SIGN */
        if (nb <= MAXSEQ)
          bound[nb++] = n;
        p++;
      } else if (p[0] == 0xC3u && p[1] == 0x97u) { /* U+00D7 MULTIPLICATION */
        p++;
      } else if ((*p >= '0' && *p <= '9') || (*p >= 'A' && *p <= 'F')) {
        char *end;
        unsigned long v = strtoul((const char *)p, &end, 16);
        if (n < MAXSEQ)
          cps[n++] = (unsigned int)v;
        p = (const unsigned char *)end - 1;
      }
    }
    if (n == 0 || nb < 2) {
      if (line[0] != '\0' && line[0] != '\n')
        unused++;
      continue;
    }

    off[0] = 0;
    for (int e = 0; e < n; e++)
      off[e + 1] = put(text, off[e], cps[e]);
    total = off[n];

    /* bound[0] is the leading boundary and bound[nb-1] the trailing one, so
     * the clusters are the nb-1 gaps between them. */
    i = 0;
    for (w = 1; w < nb; w++) {
      i = pas_text_next(text, total, i);
      if (i != off[bound[w]]) {
        fail("a grapheme boundary differs from GraphemeBreakTest.txt", line);
        break;
      }
    }
    if (w == nb && pas_text_count(text, total) != (long long)(nb - 1))
      fail("the element count differs from GraphemeBreakTest.txt", line);
    if (pas_text_validate(text, total) != -1)
      fail("the harness built ill-formed UTF-8", line);
    cases++;
  }
  fclose(f);
  return cases;
}

/* --- well-formedness ------------------------------------------------------ */

struct illformed {
  const char *bytes;
  int len;
  const char *why;
};

static int wellformedness(void) {
  /* The Unicode Standard, Table 3-7. Each of these has a lead byte that a
   * byte-count reading of UTF-8 accepts. */
  static const struct illformed bad[] = {
      {"\xC0\xAF", 2, "overlong two-byte encoding of '/'"},
      {"\xE0\x80\xAF", 3, "overlong three-byte encoding of '/'"},
      {"\xF0\x80\x80\xAF", 4, "overlong four-byte encoding of '/'"},
      {"\xC1\xBF", 2, "overlong two-byte encoding of U+007F"},
      {"\xED\xA0\x80", 3, "the first high surrogate, U+D800"},
      {"\xED\xBF\xBF", 3, "the last low surrogate, U+DFFF"},
      {"\xF4\x90\x80\x80", 4, "U+110000, above the range"},
      {"\xF5\x80\x80\x80", 4, "a lead byte no scalar has"},
      {"\xFE", 1, "a byte that is never part of UTF-8"},
      {"\xFF", 1, "a byte that is never part of UTF-8"},
      {"\xE2\x82", 2, "a truncated three-byte sequence"},
      {"\x80", 1, "a continuation byte with no lead"},
  };
  static const char *good[] = {"", "a", "\xC3\xA9", "\xE6\x97\xA5",
                               "\xF0\x9F\x98\x80", "a\xC3\xA9\xE6\x97\xA5"};
  int n = 0;

  for (size_t i = 0; i < sizeof bad / sizeof bad[0]; i++) {
    if (pas_text_validate(bad[i].bytes, bad[i].len) < 0)
      fail("accepted as well-formed UTF-8", bad[i].why);
    n++;
  }
  for (size_t i = 0; i < sizeof good / sizeof good[0]; i++) {
    if (pas_text_validate(good[i], (long long)strlen(good[i])) != -1)
      fail("refused as ill-formed UTF-8", good[i]);
    n++;
  }
  return n;
}

int main(int argc, char **argv) {
  unsigned char *listed;
  int cases, sweep, breaks, forms;

  if (argc != 2) {
    fprintf(stderr, "usage: unicode_conf <ucd-directory>\n");
    return 2;
  }

  listed = calloc(MAXCP, 1);
  if (listed == NULL)
    return 2;

  forms = wellformedness();
  cases = normalization(argv[1], listed);
  sweep = unlisted(listed);
  breaks = segmentation(argv[1]);
  free(listed);

  if (unused > 0) {
    fprintf(stderr,
            "unicode-conformance: %d line(s) of the test files looked like "
            "data and yielded no case. Either the format changed or the parser "
            "here stopped recognising it -- and a parser that compares fewer "
            "cases reports success, which is why this is counted.\n",
            unused);
    return 1;
  }

  if (failures > 0) {
    fprintf(stderr,
            "unicode-conformance: %d disagreements with Unicode %s\n",
            failures, pas_text_unicode_version());
    return 1;
  }
  printf("unicode-conformance: Unicode %s -- %d normalisation cases, %d code "
         "points swept, %d segmentation cases, %d well-formedness cases\n",
         pas_text_unicode_version(), cases, sweep, breaks, forms);
  return 0;
}
