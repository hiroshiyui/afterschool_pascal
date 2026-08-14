{ ISO 7185 §6.6.5.2's post-assertion for `reset(f)`:

    where, if f possesses the type denoted by the required type-identifier
    text and if f0.L ~ f0.R is not empty and if (f0.L ~ f0.R).last is not an
    end-of-line, then X shall be a sequence having an end-of-line component
    as its only component; otherwise, X = S( ).

  So a text file whose contents do not end in an end-of-line gets one when it
  is reset. Not a nicety: without it a program that reads back what it wrote
  loses its last line, and `eoln` at that point is D.42's error rather than
  true. This compiler stopped with a run-time error there until the BSI
  suite's CONF067 and CONF078 said otherwise.

  All three arms of the clause are here, because the appending one is easy to
  implement in a way that also appends where it must not:

    written without a writeln  -> one end-of-line appended
    written with one           -> nothing added, so no blank line appears
    nothing written at all     -> nothing added, the contents being empty }
program EolnAppended(output);
var f: text; ok: boolean;

begin
  { Not ending in an end-of-line: the appended component is what `eoln` then
    reports, and §6.4.3.5 makes the buffer variable a space at it. }
  ok := true;
  rewrite(f);
  write(f, 'A');
  reset(f);
  if f^ <> 'A' then ok := false else get(f);
  if not eoln(f) then ok := false;
  if f^ <> ' ' then ok := false;
  if eof(f) then ok := false;
  get(f);
  if not eof(f) then ok := false;
  writeln('appended  ', ok);

  { Already ending in one: X is the empty sequence, so there is no second
    line. A `while not eof do readln` over this must go round once. }
  ok := true;
  rewrite(f);
  writeln(f, 'B');
  reset(f);
  if f^ <> 'B' then ok := false else get(f);
  if not eoln(f) then ok := false;
  get(f);
  if not eof(f) then ok := false;
  writeln('unchanged ', ok);

  { Empty: the clause requires the contents to be non-empty, so a file nothing
    was written to is at end-of-file at once and has no line to end. }
  ok := true;
  rewrite(f);
  reset(f);
  if not eof(f) then ok := false;
  writeln('empty     ', ok);

  { The same rule read a line at a time, which is how a program that does not
    know it wrote the file would meet it. }
  rewrite(f);
  write(f, 'one');
  writeln(f);
  write(f, 'two');
  reset(f);
  ok := true;
  while not eof(f) do begin
    while not eoln(f) do get(f);
    readln(f);
    write('.')
  end;
  writeln;
  writeln('lines     ', ok)
end.
