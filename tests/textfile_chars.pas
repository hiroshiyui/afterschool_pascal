{ Which characters a textfile can hold, and what the prohibited one does.

  ISO 7185 §6.4.3.5 leaves "the set of characters designated prohibited from
  textfiles" to the implementation (its Annex E.6), and §6.4.3.5 then makes the
  *effect* of attributing one to a component implementation-dependent (Annex
  F.1). ISO/IEC 10206:1991 keeps both. A processor has to say what its answers
  are, and until `doc/implementation-defined.md` existed this one had never said
  anything at all — nor could it have, because no program in the corpus wrote a
  control character into a text file.

  The answers this program pins:

    - The prohibited set is exactly one character, `chr(10)`. Every other value
      of `char` — all 256 of them, `char` being a byte (ADR-0021) — survives a
      line and reads back with the ordinal it was written with.
    - Attributing `chr(10)` to a component ends the line. The character is not
      stored as data: `eoln` becomes true where it was written, and the line
      that reads back is shorter by one.

  Neither is a choice this compiler makes so much as one it inherits: a text
  file is C stdio on a POSIX system and the line separator is the newline
  byte. That is exactly what makes it worth pinning — an inherited answer is
  the kind that changes without anybody deciding to change it. }
program textfile_chars(output, scratch);

var
  scratch: text;
  c: char;
  k, n: integer;
  survived, bad: boolean;

begin
  { Every character but one goes into a line and comes back out of it. }
  bad := false;
  for k := 0 to 255 do
    begin
      rewrite(scratch);
      write(scratch, 'a');
      write(scratch, chr(k));
      write(scratch, 'b');
      writeln(scratch);

      reset(scratch);
      n := 0;
      survived := false;
      while not eoln(scratch) do
        begin
          c := scratch^;
          get(scratch);
          n := n + 1;
          { The written character is the second component of the line. }
          if n = 2 then
            survived := ord(c) = k
        end;
      if not survived then
        begin
          bad := true;
          writeln('prohibited chr(', k:1, ') left a line of ', n:1)
        end
    end;
  if not bad then
    writeln('no prohibited character');

  { And what the prohibited one does: it is the line structure itself, so a
    line written with one in the middle reads back as two lines. }
  rewrite(scratch);
  write(scratch, 'a');
  write(scratch, chr(10));
  write(scratch, 'b');
  writeln(scratch);

  reset(scratch);
  n := 0;
  while not eof(scratch) do
    begin
      if eoln(scratch) then
        begin
          n := n + 1;
          writeln('line ', n:1, ' ends')
        end;
      get(scratch)
    end;

  { A `char` is a byte, so the high half is data like any other. This is the
    other half of ADR-0021's "nothing consults the locale". }
  rewrite(scratch);
  write(scratch, chr(200), chr(0), chr(255));
  writeln(scratch);
  reset(scratch);
  write('bytes');
  while not eoln(scratch) do
    begin
      write(' ', ord(scratch^):1);
      get(scratch)
    end;
  writeln
end.
