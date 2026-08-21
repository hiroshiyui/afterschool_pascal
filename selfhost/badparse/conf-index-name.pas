{ 6.6.3.7: the index type of a conformant array schema is an
  ordinal-type-*identifier*, so a subrange written out is not one. }
program p;
procedure q(a: array [u..v: 1..2] of integer);
begin end;
begin end.
