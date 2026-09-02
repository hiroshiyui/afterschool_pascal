{ An array's index-type may span at most maxint values, that difference being
  what a subscript is lowered to, and the bound was written one too strict:
  these three spellings each span exactly maxint and each was refused. The
  first is how a program says "as wide as an index goes"; the other two are the
  same span carried down past zero, where the compiler's own test is rearranged
  against the type's own limits and so could be wrong a second way (ADR-0289).

  Only `bottom` is allocated, and that is the whole of what one can do with an
  array at this bound: maxint + 1 components is 2 GB at one byte each, so a
  variable of one would not survive the linker's small code model and every
  such array is a heap object or a type-definition. It is the shape worth
  spending the allocation on, its lower bound being where `i - lo` reaches
  exactly maxint -- the largest offset the relaxed bound now admits, and the
  value that would have wrapped had the bound been relaxed one step further. }
program index_span(output);
type
  top    = array [0..maxint] of char;
  bottom = array [-maxint..0] of char;
  across = array [-1..maxint - 1] of char;
var
  p: ^top;
  q: ^bottom;
  r: ^across;
  i: integer;
begin
  p := nil;
  r := nil;
  if (p = nil) and (r = nil) then
    writeln('two spans declared');

  new(q);
  i := -maxint;
  q^[i] := 'b';
  i := 0;
  q^[i] := 'y';
  i := -maxint;
  write('one span indexed: ', q^[i]);
  i := 0;
  writeln(q^[i]);
  dispose(q)
end.
