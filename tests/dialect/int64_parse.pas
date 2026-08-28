{ The parser's own name for ADR-0128's token, in the one place a name for a
  token is ever printed: `expected X, found Y`.

  A file of its own because the parser stops at its first error -- the same
  reason selfhost/badparse/ is one file per message -- and it is here rather
  than there because the badparse corpus was ISO 7185, where
  a literal above maxint is out of range and never becomes this token at all. }
program Int64Parse(output);
type t = 5000000000;
begin
  writeln('unreached')
end.
