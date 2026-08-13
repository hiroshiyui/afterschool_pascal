{ What `reset(input)` does, and the character it used to lose.

  §6.11.4.2 — and ISO 7185 §6.10 before it — make the effect of `reset`,
  `rewrite` or `extend` applied to the required text file `input` or `output`
  implementation-defined. `doc/implementation-defined.md` is where this
  processor's answers are written down; this program is what holds it to the
  one answer that is observable from inside a program.

  The standard input cannot be repositioned, so there is no reading of `reset`
  under which it rewinds. What it used to do instead was worse than nothing:
  it cleared the buffer variable. ADR-0021 makes `f^` one character of
  lookahead that the *stream* has already consumed, so clearing it discarded a
  character that nothing could read again — `reset(input)` between a peek and a
  read silently skipped one (ADR-0073).

  It was unreachable by the suite twice over: the fill is lazy, so a program
  that has not touched `input^` has nothing to lose, and no program in the
  corpus applied `reset` to a standard file at all. Both compilers agreed,
  because the runtime is one shared C file and neither had a reason to differ.

  The answer now is that `reset(input)` leaves the file exactly as it is. }
program resetinput(input, output);

var
  c, d: char;
  n: integer;

begin
  { A peek forces the lazy fill, so the character is in `f^` and gone from the
    stream. This is the case that lost it. }
  writeln('peek    ', input^);
  reset(input);
  writeln('after   ', input^);
  read(c);
  writeln('read    ', c);

  { And with nothing pending, `reset` costs nothing — the case that always
    looked innocent. }
  reset(input);
  read(d);
  writeln('next    ', d);

  { The rest of the line is still there and still in order, which is the
    property that says nothing was dropped along the way. }
  write('rest   ');
  while not eoln(input) do
    begin
      read(c);
      write(' ', c)
    end;
  writeln;

  { A reset does not manufacture more input either: after the line is read to
    its end, eoln still holds and readln moves on to the second line. }
  readln;
  read(n);
  writeln('number  ', n:1);

  { And it does not clear eof once the file is exhausted. }
  readln;
  reset(input);
  writeln('eof     ', eof(input))
end.
