{ A program over Plain. It is written so that both standards accept it, because
  the same source is compiled under each: what varies between the rows is the
  pair of --std flags, and a program using a dialect feature could not be one
  of them. }
program PlainUser(output);

import Plain;

var p: Pair;

begin
  p.lo := -3;
  p.hi := 7;
  writeln('plain ', Nearer(p), ' ', Total(p))
end.
