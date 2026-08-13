{ ISO/IEC 10206:1991 §6.7.5.1's `extend(f)` positions a file after its last
  component and puts it into the generating mode, so a program may append to
  what is already there. The standard input has no last component to position
  after and is not a file this program writes to, so — as with `rewrite` —
  there is no honest effect to give it. E.32 in
  `doc/implementation-defined.md` is the answer, and this is what makes it
  checkable.

  `extend(output)` is the one of the three that is not an error: the standard
  output is already positioned after everything written to it, so extending it
  is where it already is. `tests/extended/extendoutput.pas` is that half. }
program TrapExtendInput(input, output);
begin
  writeln('before');
  extend(input);
  writeln('unreachable')
end.
