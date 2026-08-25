{ PasUnicode: the two things AP 6.4.15 leaves to a library (ADR-0193).

  `ToText` is the door for bytes a program did not write -- it reports where
  6.4.15.5's assignment stops the program -- and the scalar view is what a
  program uses when it wants the code points under an element rather than the
  element itself.

  The last block is the point of having both: a family emoji is **one**
  element and **five** scalar values, and a program that needs the second
  number has no way to ask the language for it. }
program lib_unicode(output);

import PasError;
       PasUnicode;

var
  t: utf8(64);
  small: utf8(4);
  bytes: string(64);
  e: ErrorCode;
  at, n: integer;
  { 6.6.3.3 makes a var parameter's type exact, so this is `Scalar` and not
    `integer` -- which is the module saying what it hands back rather than a
    formality: a scalar value is 0..ScalarMax and nothing wider. }
  cp: Scalar;
  g: utf8(64);

procedure Try(what: string; s: string; var dest: utf8);
var code: ErrorCode;
begin
  code := ToText(s, dest);
  writeln(what, ' -> ', ErrorText(code))
end;

begin
  Try('plain     ', 'abc', t);
  Try('composed  ', 'héllo', t);
  Try('decomposed', 'héllo', t);

  { Well-formed, and it does not fit: `small` holds four bytes and three
    Japanese characters are nine. errFull and errSyntax are separate because a
    caller can act on the difference -- one is a fault in the data and the
    other in the capacity this program chose. }
  Try('too long  ', '日本語', small);

  { Not well-formed: a continuation byte with no lead. The program does not
    stop, which is the whole reason this routine exists. }
  bytes := 'ab';
  bytes[2] := chr(128);
  Try('bad bytes ', bytes, t);

  { ...and neither failure assigned anything. }
  e := ToText('kept', t);
  bytes := t;
  writeln('after failures t = ', bytes, ' (', ErrorText(e), ')');

  writeln;
  { The scalar view. NextScalar walks byte offsets and answers where the next
    one begins, or 0 -- so one loop ends at the end and on bad input alike. }
  bytes := 'héllo';
  at := 1;
  n := 0;
  while at <> 0 do begin
    at := NextScalar(bytes, at, cp);
    if at <> 0 then begin
      n := n + 1;
      writeln('  scalar ', n:2, ' = ', cp:6, '  encoded ', Encode(cp))
    end
  end;
  writeln('scalars    = ', ScalarCount(bytes):1);
  writeln('ill-formed = ', ScalarCount(bytes + chr(128)):1);

  writeln;
  e := ToText('👨‍👩‍👧', t);
  bytes := t;
  writeln('family: elements ', length(t):1,
          '  scalars ', ScalarCount(bytes):1,
          '  bytes ', length(bytes):1);
  for g in t do writeln('  and it is one element');
  writeln('the language can say the first number and not the second')
end.
