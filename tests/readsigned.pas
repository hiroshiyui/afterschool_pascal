{ Reading a number that carries a sign.

  §6.9.1 defines `read(f, v)` for a numeric v by the syntax of what it must
  accept: "the sequence of characters read shall form a signed-integer" for an
  integer variable, and a signed-number for a real one. §6.1.5 puts the sign in
  both — `signed-integer = [ sign ] unsigned-integer` — so `-42` and `+17` are
  each one datum and not a symbol followed by one. The clause also says the
  preceding characters that are spaces and end-of-lines are skipped, which is
  what makes the sign the first character that counts rather than the first
  character present.

  No file in this corpus had ever offered one. Every `.in` file held unsigned
  numbers, so the sign branch of the runtime's digit accumulator was reachable
  only through §6.7.5.5's `readstr`, and there only for an integer and only
  for `-`. A `+` and a signed real were read by nothing at all.

  The last two lines are the ones a reader is most likely to think redundant.
  A sign with no digits after it is not a signed-integer, so §6.9.1's sequence
  cannot be formed and the read is an error; the two programs that pin it are
  `trap_readsign.pas` and `trap_readsignreal.pas`, kept separate because a
  program that stops stops once. }
program ReadSigned(input, output);

var
  i, j, k, l: integer;
  r, s, t, u: real;

begin
  { Both signs, an unsigned datum between them, and the fourth on the next
    line — so the skipping of end-of-lines happens with a sign waiting. }
  read(i, j, k, l);
  writeln(i:1, ' ', j:1, ' ', k:1, ' ', l:1);

  { §6.1.5's signed-number: a sign in front of every real form there is —
    a fractional part, a scale factor, and both at once. The leading spaces
    are skipped before the sign is seen. }
  read(r, s, t, u);
  writeln(r:9:4);
  writeln(s:9:4);
  writeln(t:12:4);
  writeln(u:12:4);

  { A sign is not the datum's only character, so what follows it is read as
    part of the same number: `-0` and `+0` are the zero, and reading them back
    out shows the sign did not survive into a value it should not be in. }
  read(i, j);
  writeln(i:1, ' ', j:1, ' ', i = j)
end.
