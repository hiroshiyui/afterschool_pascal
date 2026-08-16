{ ISO 7185 §6.6.4.1: `write` may be the program's own procedure, and then the
  statement `write(i)` activates it. The parser had to recognise the six
  read/write spellings to parse a write-parameter-list's field widths at all,
  so it builds a WriteStmt either way and Sema hangs the real call off it; the
  node the parser built is then a husk (ADR-0087).

  What this case pins is that the *dump* shows the call and not the husk, at
  the indentation of the statement that is really there. Reaching it through
  the husk padded twice -- once for the node that is not printed and once for
  the call -- so the head line sat two levels deeper than its own arguments,
  and no golden in the tree passed a --dump flag over a program that redefines
  the family. The `assign` above it is here to be compared against: the two
  statements are siblings and must print at one level.

  --dump-sema rather than --dump-all, because the husk is only looked through
  after Sema: before it the field is nil, which is the honest picture of a
  parser that recognised a name and could not know whether that reading would
  survive. }
program RedefineFamily(output);
var i: integer;

procedure write(var a: integer);
begin
  a := a + 1
end;

begin
  i := 1;
  write(i)
end.
