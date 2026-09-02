{ Text as characters rather than bytes: `utf8(n)` and PasUnicode.

  A `string(n)` is n bytes and `s[i]` is a byte, which is what Turbo Pascal
  meant too. A `utf8(n)` (AP 6.4.15) holds up to n bytes of UTF-8 in normal
  form C; `length` counts what a reader would call characters -- extended
  grapheme clusters -- and `for g in t` walks them. PasUnicode gives the
  code points underneath when a program wants those, and case folding for
  a comparison that ignores case. }
program graphemes(output);

import PasError; PasUnicode;

var
  t, g: utf8(64);
  bytes: string(64);
  a, b: string(64);
  n: integer;
  e: ErrorCode;

begin
  t := 'héllo, 世界';
  bytes := t;
  writeln(t, ': ', length(t):1, ' characters in ', length(bytes):1, ' bytes');

  { Two spellings of é -- one code point, or e followed by a combining
    acute (bytes 204 129) -- become one value on assignment, so comparing
    two texts is a byte comparison and answers what a reader would. }
  g := 'he' + chr(204) + chr(129) + 'llo';
  writeln('composed = decomposed: ', g = 'héllo');

  n := 0;
  for g in t do begin
    n := n + 1;
    if n <= 3 then writeln('  element ', n:1, ' = ', g)
  end;

  { A family emoji is one character to a reader and five code points
    joined by zero-width joiners: the language answers the first number,
    the library the second. }
  t := '👨‍👩‍👧';
  bytes := t;
  writeln('family: ', length(t):1, ' element, ', ScalarCount(bytes):1,
          ' code points, ', length(bytes):1, ' bytes');

  { Folding is not lowercasing: ß folds to ss, so these compare equal
    under Fold and would not under Lower. }
  e := Fold('Straße', a);
  e := Fold('STRASSE', b);
  writeln('fold(Straße) = ', a, ', equal to fold(STRASSE): ', a = b);

  { Bytes a program did not write go through ToText, which reports
    instead of stopping the program: a lone continuation byte is errSyntax
    and nothing is assigned. }
  bytes := 'ab';
  bytes[2] := chr(128);
  e := ToText(bytes, t);
  writeln('bad byte: ', ErrorText(e))
end.
