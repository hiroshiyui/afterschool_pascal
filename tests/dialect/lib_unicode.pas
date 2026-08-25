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
  tiny: string(4);
  bad: string(4);
  { 6.6.3.3 makes a var parameter's type exact, so this is `Scalar` and not
    `integer` -- which is the module saying what it hands back rather than a
    formality: a scalar value is 0..ScalarMax and nothing wider. }
  cp: Scalar;
  g: utf8(64);
  elems: string(64);
  piece: string(64);
  k: integer;

procedure Try(what: string; s: string; var dest: utf8);
var code: ErrorCode;
begin
  code := ToText(s, dest);
  writeln(what, ' -> ', ErrorText(code))
end;

{ A range of elements out of the middle, which is what an index would have
  been for -- and it is nine lines of program over `ElementEnd` rather than a
  routine of the module's, so the walk is written where it costs (ADR-0199).

  The bytes come back rather than a text, because a slice taken at element
  boundaries is already in normal form and `ToText` is the door back. }
procedure Take(s: string; first, count: integer; var slice: string);
var at, nxt, n: integer;
begin
  slice := '';
  at := 1;
  n := 0;
  repeat
    nxt := ElementEnd(s, at);
    if nxt <> 0 then begin
      n := n + 1;
      if (n >= first) and (n < first + count) then
        slice := slice + substr(s, at, nxt - at);
      at := nxt
    end
  until (nxt = 0) or (n >= first + count - 1)
end;

{ Two texts walked in lockstep: the number of elements they share as a prefix.
  This is the shape `for g in t` cannot take, a for-statement having one
  operand and one control variable. }
function CommonPrefix(a, b: string): integer;
var pa, pb, na, nb, n: integer;
    ok: boolean;
begin
  pa := 1;
  pb := 1;
  n := 0;
  ok := true;
  while ok do begin
    na := ElementEnd(a, pa);
    nb := ElementEnd(b, pb);
    if (na = 0) or (nb = 0) then ok := false
    else if substr(a, pa, na - pa) <> substr(b, pb, nb - pb) then ok := false
    else begin
      n := n + 1;
      pa := na;
      pb := nb
    end
  end;
  CommonPrefix := n
end;

begin
  bad := 'ab';
  bad[2] := chr(128);
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
  writeln('the language can say the first number and not the second');

  writeln;
  { Case, and the point of having three routines rather than two.

    **Folding is not lowercasing.** The German sharp s lowercases to itself
    and folds to `ss`, so two words that differ only in case compare equal
    under Fold and unequal under Lower -- which is why a caseless comparison
    is Fold's job and not Lower's. The two lines below are that difference,
    printed. }
  e := Upper('straße', bytes);  writeln('upper       = ', bytes);
  e := Lower('STRASSE', bytes);   writeln('lower       = ', bytes);
  e := Fold('STRASSE', bytes);    writeln('fold STRASSE= ', bytes);
  e := Fold('straße', bytes);   writeln('fold straße = ', bytes);
  writeln('caseless equal? see the two folds above');

  { A full mapping can make one character two, so the result may be longer
    than the source and a destination the size of it is not enough. }
  e := Upper('ǳ', bytes);      writeln('digraph up  = ', bytes);

  { **The declined half, printed.** Greek lowercases its final sigma to ς and
    every other sigma to σ, and which one a letter is depends on where the
    *word* ends. That mapping is conditional, so it is declined with the rest
    of the locale (ADR-0189, ADR-0196) and the line below ends in σ. It is
    here rather than left out because a reader should meet the limitation in
    the test rather than discover it in a program: this library knows no
    language, and Greek is where that is most visible. }
  e := Lower('ΣΟΦΟΣ', bytes);   writeln('greek lower = ', bytes,
                                        '  (final sigma is not special-cased)');

  { errFull rather than a truncation, and it is the caller's capacity that
    decides -- `tiny` holds four bytes and `straße` folds to seven. }
  writeln('into 4 bytes  ', ErrorText(Fold('straße', tiny)));
  writeln('ill-formed    ', ErrorText(Fold(bad, bytes)));

  writeln;
  { The element walk. AP 6.4.15.9 refuses an integer index and argues for the
    refusal; `for g in t` is the answer for a program that walks a text once,
    start to end, and `ElementEnd` is for the cases that are not that
    (ADR-0199).

    The text below is five elements and twenty-two bytes, and the family
    emoji in the middle is one element of eighteen -- so an index over
    elements, an index over scalars and an index over bytes would each name a
    different thing at the same number. That is NOTE 12's argument, made with
    a value. }
  e := ToText('ab👨‍👩‍👧cd', t);
  elems := t;
  writeln('elements ', length(t):1, '  bytes ', length(elems):1);

  k := 1;
  at := 1;
  repeat
    n := ElementEnd(elems, at);
    if n <> 0 then begin
      writeln('  element ', k:1, ' is ', (n - at):2, ' bytes');
      k := k + 1;
      at := n
    end
  until n = 0;

  { A range out of the middle: the one thing an index was wanted for. }
  Take(elems, 2, 3, piece);
  writeln('elements 2..4 = ', piece, ' (', length(piece):1, ' bytes)');

  { And back to a text, which cannot fail for want of normal form: a slice cut
    at element boundaries is already in it. }
  writeln('back to a text: ', ErrorText(ToText(piece, t)));

  { Lockstep, the shape a for-statement cannot take. }
  writeln('common prefix with ab👨‍👩‍👧xy = ',
          CommonPrefix(elems, 'ab👨‍👩‍👧xy'):1, ' elements');

  { And the walk terminates on bytes nobody vouched for, which is what a
    caller wants from input it did not write. `bad` is a letter and then a
    continuation byte with no lead: the first element is the letter and ends
    normally, and the walk stops where the ill-formed byte begins rather than
    at the end of the string -- which is the difference between a loop that
    terminates and one that reports. }
  writeln('ill-formed: element 1 ends at ', ElementEnd(bad, 1):1,
          ', and from there ', ElementEnd(bad, 2):1)
end.
