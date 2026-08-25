/* Afterschool Pascal runtime library -- the text primitives.
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

/* AP 6.4.15's two properties, and nothing else.
 *
 * A text value is well-formed UTF-8 in Normalization Form C whose elements are
 * extended grapheme clusters (ADR-0189). Everything in this header serves one
 * of those two sentences: pas_text_validate and pas_text_nfc are what
 * establish the invariant where a value is constructed, and pas_text_next and
 * pas_text_count are what read the element sequence back out.
 *
 * These are `pas_` and not `pasx_` because the code generator will name them
 * (ADR-0131): a program may not bind them, and ReservedForeignName refuses
 * them. Nothing emits a call yet -- this is the runtime half of AP 6.4.15,
 * landed on its own so that the Unicode Character Database's own conformance
 * files can judge it before any of the language rests on it.
 *
 * The tables are runtime/pasrt_unicode_data.h, generated from the database by
 * runtime/unicode/generate.py. The version is PAS_UNICODE_VERSION there, and
 * AP 6.4.15.12 is what requires it to be stated. */
#ifndef APASCAL_PASRT_UNICODE_H
#define APASCAL_PASRT_UNICODE_H

/* What pas_text_nfc answers instead of a length. A caller distinguishes them
 * from a length by the sign and nothing else, there being no length below
 * zero. */
#define PAS_TEXT_ILLFORMED (-1) /* the source is not well-formed UTF-8 */
#define PAS_TEXT_OVERFLOW (-2)  /* the result does not fit the destination */
#define PAS_TEXT_SEGMENT (-3)   /* one starter carries more marks than fit */

/* The version of the Unicode Standard this was built against. */
const char *pas_text_unicode_version(void);

/* -1 when every byte of s[0..n) is part of a well-formed UTF-8 sequence, and
 * otherwise the index of the first byte that is not. Overlong encodings, the
 * surrogate range and anything above U+10FFFF are all ill-formed, so this is
 * the whole of AP 6.4.15.2's first half. */
long long pas_text_validate(const char *s, long long n);

/* Normalization Form C of s[0..n) into dst[0..cap), answering the number of
 * bytes written or one of the PAS_TEXT_* statuses above. dst and s shall not
 * overlap. */
long long pas_text_nfc(const char *s, long long n, char *dst, long long cap);

/* The byte offset just past the extended grapheme cluster beginning at `at`,
 * which shall be 0 or an offset this returned. Answers n when at >= n, so a
 * loop terminates on the answer rather than on a separate test.
 *
 * The bytes are assumed well-formed, that being the invariant of the type this
 * serves; an ill-formed byte is treated as one element so that a caller given
 * bad input still terminates. */
long long pas_text_next(const char *s, long long n, long long at);

/* Case folding and case mapping, all three *full*: one code point may become
 * three, so none can be done in place and each answers the length written or a
 * negative PAS_TEXT_* status.
 *
 * Folding is what a caseless comparison needs -- `fold(a) = fold(b)` is the
 * question "are these the same word but for case", and it is not the same as
 * lowercasing both: the German sharp s folds to two letters and lowercases to
 * itself. Every locale- or context-conditional mapping is declined, so these
 * know nothing about any language (ADR-0196).
 *
 * Case mapping does not preserve normal form, so a caller putting the result
 * back into a text-type normalises it there -- which AP 6.4.15.5's assignment
 * does anyway. */
long long pas_text_fold(const char *s, long long n, char *dst, long long cap);
long long pas_text_upper(const char *s, long long n, char *dst, long long cap);
long long pas_text_lower(const char *s, long long n, char *dst, long long cap);

/* One scalar value at byte offset `at`. Answers the bytes it occupies, or 0
 * when the sequence there is not well-formed; the value goes to *out.
 *
 * Exported so that a library binding can decode without a second reading of
 * The Unicode Standard's table 3-7 (ADR-0193). Nothing in the language calls
 * it: AP 6.4.15 has no scalar view, and a program that wants one goes through
 * PasUnicode. */
long long pas_text_scalar_at(const char *s, long long n, long long at,
                             unsigned int *out);

/* How many extended grapheme clusters s[0..n) has -- AP 6.4.15.8's `length`,
 * and not a constant-time operation (that clause's NOTE 11). */
long long pas_text_count(const char *s, long long n);

#endif /* APASCAL_PASRT_UNICODE_H */
