{ ISO/IEC 10206:1991 §6.7.5.5 makes the first comma of both parameter lists
  part of the grammar, not an option: the string is a parameter of a different
  kind from every one after it, so a `readstr` whose list is one expression has
  no reading in it at all -- unlike `readln`, which may be written with no list
  and only finishes a line.

  Since ADR-0087 that is a rule about the *statement* rather than about the
  tokens. §6.6.4.1 lets a program declare its own `readstr`, so the parser
  cannot commit to `'(' string-expression ','` -- it reads a plain parameter
  list and Sema, which by then knows what the name denotes, is what finds the
  string missing. The rule is unchanged and the message comes from one pass
  later.

  This is a program a person would not write, and that is the point: a corpus
  that always writes the comma cannot tell a compiler that requires it from
  one that does not. The writestr half is in stringtransfer_comma2.pas. }
program StringTransferComma(output);
var i: integer;
begin
  readstr('1 2');
  writeln(i:1)
end.
