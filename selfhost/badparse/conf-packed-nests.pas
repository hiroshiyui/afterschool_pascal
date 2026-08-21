{ 6.6.3.7's grammar gives the packed form exactly one index-type-specification
  and a type-identifier component: only the unpacked form nests. }
program p;
procedure q(a: packed array [u..v: integer; j..k: integer] of char);
begin end;
begin end.
