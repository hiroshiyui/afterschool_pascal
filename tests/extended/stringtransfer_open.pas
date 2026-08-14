{ §6.7.5.5's parameter list is not optional either: `readstr` alone is not a
  statement, where `readln` alone is one.

  Two messages, not one, and that is the change ADR-0087 made: the parser used
  to stop at the missing '(' because it had committed to the shape of the
  list, and it no longer commits -- §6.6.4.1 lets the program declare its own
  `readstr`, so what the word denotes is not known until Sema. Sema
  accumulates, so both halves of the same broken statement are reported.

  The second is also what says a broken readstr is not given `input`: it reads
  from a string and from no file at all, so complaining that the program does
  not list `input` would name a rule this program is not breaking. }
program StringTransferOpen(output);
var i: integer;
begin
  readstr;
  writeln(i:1)
end.
