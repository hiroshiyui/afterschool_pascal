{ Sema does not stop at its first error, so unlike badparse/ one file can carry
  many. These are the expression rules. }
program expressions(output);
type colour = (red, green);
var i: integer; b: boolean; c: char; r: real;
    s5: packed array [1..5] of char;
    s3: packed array [1..3] of char;
procedure q; begin end;
begin
  i := undeclaredname;
  i := q;
  i := colour;
  b := not i;
  i := -b;
  i := i div b;
  b := b and i;
  b := i and b;
  b := s5 = s3;
  b := c < red;
  i := i mod r;
  c := '';
  write(i, b, c, r, s5, s3)
end.
