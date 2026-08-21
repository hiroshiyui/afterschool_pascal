{ 6.6.3.7: the component is a type-identifier or another conformant array
  schema, and a record written out in full is neither. }
program p;
procedure q(a: array [u..v: integer] of record x: integer end);
begin end;
begin end.
