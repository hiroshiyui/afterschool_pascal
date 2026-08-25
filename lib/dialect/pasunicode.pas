{ PasUnicode -- what AP 6.4.15 leaves to a library.

  The text-type is what a program holds when it means the characters, and the
  language gives it everything a *type* needs: a value, an assignment that
  establishes normal form, a comparison, a length in elements, and an
  iteration (ADR-0189 - ADR-0192). Two things it deliberately does not give,
  and this module is both.

  **A conversion that reports.** AP 6.4.15.5 makes ill-formed bytes an error
  that stops the program, which is 6.4.6's model for a constrained type and
  the right one for a program's own literals and its own capacities. It is the
  wrong one for bytes off a socket or out of a file, which a program did not
  write and cannot vouch for. `ToText` is that door: it answers an ErrorCode
  and assigns nothing when the bytes are not what they claim.

  **A scalar view.** An element of a text is an extended grapheme cluster and
  a program sometimes wants the code points under one -- to classify a
  character, to write an escape, to implement something Unicode specifies in
  terms of scalars. 6.4.15 has no such view and should not: three sequences
  live in one text and a type that offered all three would have to say, at
  every operation, which it meant.

  **This module is a binding** in lib/dialect/README.md's sense: it exports
  Pascal and keeps the `external` directive to itself. Both routines below go
  to the runtime rather than doing the work here, and that is the decision
  worth defending -- a UTF-8 decoder written in Pascal would be a second
  reading of The Unicode Standard's table 3-7, and that table needs care for
  exactly the reason a second reading would get it wrong: an overlong
  encoding, a surrogate and a code point above the range each have a lead byte
  that looks ordinary. One reading, in one place, checked by
  `unicode-conformance` against Unicode's own files (ADR-0190).

  **An element walk a program drives.** AP 6.4.15.9 refuses an integer index
  on the type and argues for the refusal rather than apologising for it: three
  sequences live in one value and an index would have to choose silently which
  it names, and an index over the elements cannot be constant-time over this
  representation. `for g in t` is what the language gives instead, and it is
  the whole answer for a program that walks a text once, start to end.
  `ElementEnd` is for the three things it is not -- two texts walked in
  lockstep, a walk that stops and resumes, and a range of elements taken out
  of the middle -- and it is a *boundary* rather than a slice, so the loop
  stays in the program that pays for it (ADR-0199).

  What is **not** here, and each is a decision rather than a gap: an
  `ElementAt(t, n)`, a `Slice(t, first, count)`, and anything else that walks
  n elements while reading like an index (ADR-0196, ADR-0199).

  A restriction, and it is the one every foreign string call here has: a value
  containing `chr(0)` cannot be passed, because a `string` crosses as a
  NUL-terminated copy and the marshalling traps rather than truncating
  (ADR-0122). U+0000 is a scalar value like any other, so a text holding one
  is a text this module cannot be asked about. }

module PasUnicode;

export PasUnicode = (Scalar, ScalarMax, ScalarBytes, Utf8Char, CaseMax,
                     ToText, NextScalar, ScalarCount, Encode,
                     Fold, Upper, Lower, ElementEnd);

import PasError;

const
  { ISO/IEC 10646's whole range. A scalar value is one of these that is not a
    surrogate; the gap is not expressible as a Pascal subrange, so it is a
    property of the values this module hands back rather than of the type. }
  ScalarMax = 1114111;

  { The most bytes one scalar occupies in UTF-8. Four since 2003, when
    RFC 3629 cut the encoding at U+10FFFF to match UTF-16's reach. }
  ScalarBytes = 4;

  { The largest result the three case routines will hand back. A full case
    mapping can make one code point three, so a bound is needed and this is
    it; a caller wanting more than this needs a different interface, not a
    bigger constant, because the value comes back through a `?string(n)` whose
    capacity is part of the type. }
  CaseMax = 1024;

type
  Scalar = 0..ScalarMax;
  Utf8Char = string(ScalarBytes);

{ The bytes of `s`, as a text of the caller's own capacity.

  `errNone` and `t` holds the value; `errSyntax` and the bytes are not
  well-formed UTF-8; `errFull` and they are, and their normal form does not fit
  `t`. Nothing is assigned unless the answer is `errNone`.

  The two failures are separate because a caller can act on the difference: one
  is a fault in the data and the other in the capacity the program chose. }
function ToText(s: string; var t: utf8): ErrorCode;

{ The scalar value beginning at byte `at`, and the byte where the next one
  begins -- 0 when `at` is past the end, or when the bytes there are not
  well-formed.

  Indices are byte offsets into `s`, 1-based as every Pascal string index is.
  A loop is therefore

    at := 1;
    while at <> 0 do at := NextScalar(s, at, cp);

  and it terminates on ill-formed input as well as at the end, which is what a
  caller wants from bytes it did not write. }
function NextScalar(s: string; at: integer; var cp: Scalar): integer;

{ How many scalar values the bytes of `s` represent, or **-1** when they are
  not well-formed UTF-8.

  Not the same number as `length` of a text made from them: that counts
  extended grapheme clusters, and one cluster is one or more scalars. }
function ScalarCount(s: string): integer;

{ `s` with every character case-folded, written into `out`.

  **Folding is not lowercasing**, and it is the operation a caseless comparison
  wants: `Fold(a) = Fold(b)` asks "are these the same but for case", where
  comparing two lowercased values gets the German sharp s wrong -- it folds to
  `ss` and lowercases to itself. Unicode publishes the mapping for exactly this
  purpose and it is the only one of the three that is *for* comparing.

  `errNone`, or `errFull` when the result does not fit `out` -- a full mapping
  can make one character three, so a destination the size of the source is not
  enough in general -- or `errSyntax` when the bytes are not well-formed UTF-8.
  Nothing is written unless the answer is `errNone`. }
function Fold(s: string; var out: string): ErrorCode;

{ `s` with every character mapped to upper or to lower case, into `out`.

  Full mappings, so `Upper` of the German sharp s is `SS` and the result may be
  longer than the source. The same three answers as `Fold`.

  **Neither consults a locale**, and that is a decision rather than a gap: the
  conditional mappings Unicode publishes name a language or a context -- final
  sigma, the Turkish dotless i -- and this language reads no environment
  variable to decide what a program means (ADR-0189). A program that needs
  Turkish casing needs a Turkish library.

  **Neither preserves normal form**, so a result going into a text-type is
  normalised there. AP 6.4.15.5's assignment does that anyway, which is why
  `Upper` answers bytes and not a text. }
function Upper(s: string; var out: string): ErrorCode;
function Lower(s: string; var out: string): ErrorCode;

{ Where the element beginning at byte `at` ends: the 1-based offset of the
  next element, or 0 when `at` is past the end of `s` or the bytes of that
  element are not well-formed UTF-8.

  The element itself is `substr(s, at, ElementEnd(s, at) - at)`, taken by the
  caller. That is the point rather than an omission: this routine answers a
  boundary, so the walk and the copy are both written in the program, and no
  call of it is O(n) in the elements before `at`.

    at := 1;
    repeat
      nxt := ElementEnd(s, at);
      if nxt <> 0 then begin
        g := substr(s, at, nxt - at);
        ...
        at := nxt
      end
    until nxt = 0;

  An element is one or more scalar values -- a base character and its combining
  marks, a Hangul syllable however it was written, an emoji sequence joined by
  zero-width joiners -- so it is neither `NextScalar`'s unit nor a byte. It is
  what `length` of a text counts and what `for g in t` yields.

  **A text is not a parameter here**, as nothing in this module takes one: the
  bytes are what cross, and a text becomes them by assignment. A slice of a
  text taken at element boundaries is already in normal form, so converting one
  back with `ToText` cannot fail for want of normalisation -- which is the
  property `tests/dialect/text_join.pas` pins by walking a text and joining the
  pieces back to the original (ADR-0192). }
function ElementEnd(s: string; at: integer): integer;

{ One scalar value as its UTF-8 bytes.

  The null-string for a surrogate or for anything above ScalarMax, neither of
  which is a scalar value and neither of which UTF-8 encodes. Written here
  rather than bound to the runtime because encoding is unambiguous arithmetic
  -- it is *decoding* that table 3-7 is about. }
function Encode(cp: Scalar): Utf8Char;

end;

{ The two the runtime answers. Both take the value as a NUL-terminated copy,
  which is what a `string` value parameter becomes at the boundary. }

{ 0 well-formed and fits, 1 not well-formed, 2 does not fit. }
function ExtCheck(s: string; cap: integer): integer;
  external 'pasx_text_check';

{ The 1-based offset of the scalar after the one at `at`, or 0. }
function ExtScalar(s: string; at: integer; var cp: integer): integer;
  external 'pasx_text_scalar';

{ The 1-based offset of the element after the one at `at`, or 0. The segment
  rules are UAX #29's and belong with the tables that decide them, which is the
  same argument the decoder is bound for rather than written here. }
function ExtElement(s: string; at: integer): integer;
  external 'pasx_text_element';

{ The three cases, and the shape is PasDir.Next's: the value comes back
  through an optional and the *caller's* capacity goes in, so the bound checked
  is the one the program declared rather than one this module chose. }
type CaseText = string(CaseMax);
     OptCaseText = ?CaseText;

function ExtFold(s: string; cap: integer;
                 var status: integer): OptCaseText;
  external 'pasx_text_fold';
function ExtUpper(s: string; cap: integer;
                  var status: integer): OptCaseText;
  external 'pasx_text_upper';
function ExtLower(s: string; cap: integer;
                  var status: integer): OptCaseText;
  external 'pasx_text_lower';

function ToText;
var status: integer;
begin
  { The capacity is read from the actual -- `var t: utf8` is a schematic
    formal and AP 6.4.15.1 gives `utf8` the same one discriminant `string`
    has, so this asks the caller's own bound and not a bound of this
    module's choosing. }
  status := ExtCheck(s, t.capacity);
  if status = 1 then
    ToText := errSyntax
  else if status = 2 then
    ToText := errFull
  else begin
    { Checked, so 6.4.15.5's two errors cannot fire here. This is the one
      place in the module where the language's own conversion is used, and it
      is used only after the question it would have stopped on is answered. }
    t := s;
    ToText := errNone
  end
end;

function NextScalar;
var v, next: integer;
begin
  v := 0;
  next := ExtScalar(s, at, v);
  { `cp` is a subrange of 0..ScalarMax and the runtime answers with a scalar
    value or nothing, so the store cannot be out of range -- but it is written
    only when there was one, because a caller that ignores the result should
    not find a value that no byte produced. }
  if next <> 0 then cp := v;
  NextScalar := next
end;

function ScalarCount;
var at, n, cp: integer;
begin
  at := 1;
  n := 0;
  while at <> 0 do begin
    at := ExtScalar(s, at, cp);
    if at <> 0 then n := n + 1
  end;
  { The loop stops for two reasons and they are not the same answer: reaching
    the end, and meeting a byte that is not part of a well-formed sequence.
    Counting what was read up to a fault would report a length for bytes that
    have none, so the whole value is asked about again -- once, with the
    capacity that always fits, so only the well-formedness half can fail. }
  if ExtCheck(s, length(s) * 3 + 4) = 1 then
    ScalarCount := -1
  else
    ScalarCount := n
end;

{ One body for three routines would need a procedural parameter over an
  `external` function, and 6.6.3.1's procedural parameter is a code-and-link
  pair (ADR-0030) where a foreign routine has no link. So the three are
  written out, and the duplication is three lines each. }
function Fold;
var got: OptCaseText; status: integer;
begin
  status := 0;
  got := ExtFold(s, out.capacity, status);
  if got = nil then
    if status = 1 then Fold := errFull else Fold := errSyntax
  else begin
    out := got^;
    Fold := errNone
  end
end;

function Upper;
var got: OptCaseText; status: integer;
begin
  status := 0;
  got := ExtUpper(s, out.capacity, status);
  if got = nil then
    if status = 1 then Upper := errFull else Upper := errSyntax
  else begin
    out := got^;
    Upper := errNone
  end
end;

function Lower;
var got: OptCaseText; status: integer;
begin
  status := 0;
  got := ExtLower(s, out.capacity, status);
  if got = nil then
    if status = 1 then Lower := errFull else Lower := errSyntax
  else begin
    out := got^;
    Lower := errNone
  end
end;

function ElementEnd;
begin
  { One call, one answer. The runtime validates the element it names rather
    than the whole string, so a walk of n elements stays linear -- validating
    from the start on every call would make it quadratic and would still be
    answering a question the caller did not ask. }
  ElementEnd := ExtElement(s, at)
end;

function Encode;
var r: Utf8Char;
begin
  r := '';
  { 6.8.2.2 makes every read of the function identifier a recursive call, so
    the result is accumulated in a local and assigned once -- the convention
    every function in lib/ follows. }
  if (cp >= 55296) and (cp <= 57343) then
    { A surrogate is not a scalar value: ISO/IEC 10646 reserves the range for
      UTF-16's own encoding and UTF-8 has no representation for one. }
    r := ''
  else if cp < 128 then
    r := chr(cp)
  else if cp < 2048 then
    r := chr(192 + cp div 64) + chr(128 + cp mod 64)
  else if cp < 65536 then
    r := chr(224 + cp div 4096) +
         chr(128 + (cp div 64) mod 64) +
         chr(128 + cp mod 64)
  else
    r := chr(240 + cp div 262144) +
         chr(128 + (cp div 4096) mod 64) +
         chr(128 + (cp div 64) mod 64) +
         chr(128 + cp mod 64);
  Encode := r
end;

end.
