{ ISO/IEC 10206:1991 §6.7.5.5 makes the first comma of both parameter lists
  part of the grammar, not an option: the string is a parameter of a different
  kind from every one after it, so a `readstr` whose list is one expression has
  no reading in it at all -- unlike `readln`, which may be written with no list
  and only finishes a line.

  A parser stops at its first error, so this is a file of its own; the
  writestr half of the same rule is in stringtransfer_comma2.pas. Neither is a
  program a person would write, and that is the point: a corpus that always
  writes the comma cannot tell a parser that requires it from one that does
  not. }
program StringTransferComma(output);
var i: integer;
begin
  readstr('1' i);
  writeln(i:1)
end.
