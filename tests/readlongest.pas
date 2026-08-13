{ How much of the input one `read` of a number consumes.

  §6.9.1 d) does not say "read a number"; it says the sequence read "shall,
  and s ~ S(t.first) shall not, form a signed-number according to the syntax of
  6.1.5". That is the longest prefix that *is* a number and not one character
  more — so what a read leaves behind is as much a part of its specification as
  the value it produces, and the two are only separable in a program that reads
  something else afterwards. This is that program.

  §6.1.5 makes both halves of a real obligatory —
  `unsigned-real = digit-sequence '.' fractional-part [ 'e' scale-factor ]`,
  and `scale-factor = [ sign ] digit-sequence` — so:

    1.      is the integer 1, then a point
    .5      is not a number at all
    2e      is the integer 2, then a letter
    2e+     is the integer 2, then a letter and a sign

  A file offers one character of lookahead (ADR-0021), which is one short of
  deciding any of them: the point has to be consumed before what follows it can
  be seen. So the runtime gives back what it over-read — at most a point, or an
  `e` and the sign after it — and the character it gives back is the one that
  was written, `E` staying `E`.

  Nothing had ever looked. Every `.in` file in this corpus held numbers with
  nothing interesting after them, so the reader consumed `1.` as a real and
  `2e+` as one too, and every oracle agreed. The two lines this pins hardest
  are `7..9` — which is what a subrange looks like, so a program reading its own
  source-like input would have lost the `..` — and `8.5.5`, which was already
  right and is here so that a fix in the wrong direction fails as well. }
program ReadLongest(input, output);

var
  r: real;
  c: char;

{ One line: the number, then every character the read did not take. }
procedure line;
begin
  read(r);
  write(r:12:4, ' rest=[');
  while not eoln do begin
    read(c);
    write(c)
  end;
  readln;
  writeln(']')
end;

begin
  line;   { -1.abc  — the point is not part of the number }
  line;   { 1.5e    — nor is a scale factor with no digits }
  line;   { 2e+     — nor its sign }
  line;   { 6.0E    — and the case of the letter survives }
  line;   { 7..9    — both points come back }
  line;   { 1.e5    — a point with digits only on the right is not a number }
  line;   { 3.4e5x  — a complete real, and only the x is left }
  line    { 8.5.5   — the second point ends it, which was always so }
end.
