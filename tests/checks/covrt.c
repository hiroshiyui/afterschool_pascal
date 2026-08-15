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

/* The callback side of SanitizerCoverage, for tests/checks/coverage.py.
 *
 * This is *not* part of the Pascal runtime and must never be linked into a
 * user's program: runtime/pasrt.c is what the compiler's product depends on,
 * and this file is a measuring instrument for one test. It lives under
 * tests/checks/ to keep that distinction physical.
 *
 * Why a shim at all. `-fsanitize-coverage=` is an *IR* pass, so clang applies
 * it to the textual .ll this compiler emits without needing a front end, a
 * source language, or debug info -- which is the whole reason coverage is
 * measurable here at all. What the pass does not supply is the callback it
 * emits calls to. clang's own libclang_rt would supply it, but linking that
 * drags in the UBSan standalone archive, which Debian's clang packages do not
 * ship; twenty lines is cheaper than that dependency and does not vary with
 * the LLVM packaging.
 *
 * Two files come out, both keyed on the same guard numbering:
 *
 *   PASCOV_PCS   the whole table, written once: every instrumented address,
 *                which is the *denominator* and must not depend on what ran
 *   PASCOV_OUT   the addresses this process reached, appended -- so a corpus
 *                of many runs accumulates into one file
 */

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

static const uintptr_t *g_pcs;
static size_t g_npcs;
static uint8_t *g_hit;

/* Called once per instrumented module before main. The guards start zeroed and
 * are numbered from 1, because 0 is how the callback recognises a guard that
 * was never initialised. */
void __sanitizer_cov_trace_pc_guard_init(uint32_t *start, uint32_t *stop) {
  static uint32_t n;
  if (start == stop || *start) return;
  for (uint32_t *p = start; p < stop; p++) *p = ++n;
  free(g_hit);
  g_hit = calloc((size_t)n + 2, 1);
}

/* The pc-table: two words per instrumented point, the address and a flag whose
 * low bit marks a function entry. Its order matches the guard numbering, which
 * is what lets one index serve both. */
void __sanitizer_cov_pcs_init(const uintptr_t *beg, const uintptr_t *end) {
  g_pcs = beg;
  g_npcs = (size_t)(end - beg) / 2;
}

void __sanitizer_cov_trace_pc_guard(uint32_t *guard) {
  if (*guard && g_hit) g_hit[*guard] = 1;
}

/* A destructor rather than an atexit hook, so a compiler run that ends in
 * halt(1) -- which every diagnostic case does -- still reports what it
 * reached. Those runs are a third of the corpus and they are the only thing
 * that reaches the error paths, so losing them would silently understate
 * coverage rather than fail. */
__attribute__((destructor)) static void pascov_dump(void) {
  const char *out = getenv("PASCOV_OUT");
  const char *tab = getenv("PASCOV_PCS");
  FILE *f;
  size_t i;

  if (!out || !g_hit || !g_pcs) return;

  if (tab) {
    f = fopen(tab, "w");
    if (f) {
      for (i = 0; i < g_npcs; i++)
        fprintf(f, "%zx %d\n", (size_t)g_pcs[2 * i], (int)(g_pcs[2 * i + 1] & 1));
      fclose(f);
    }
  }

  f = fopen(out, "a");
  if (!f) return;
  for (i = 0; i < g_npcs; i++)
    if (g_hit[i + 1]) fprintf(f, "%zx\n", (size_t)g_pcs[2 * i]);
  fclose(f);
}
