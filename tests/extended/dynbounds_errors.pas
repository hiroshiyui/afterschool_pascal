{ Where 6.2.3.8 b)'s offer is *not* made, and what is said instead (ADR-0113).

  The clause puts a subrange-bound in the block's commencement only where it is
  "closest-contained by ... the block" -- which a variable's own denoter is. A
  type-definition is not one: its type would outlive no activation in
  particular and every variable of it would need a descriptor of its own, which
  is a second decision about who owns one and is not taken here. A field's
  denoter is not one either: the record's storage is sized where the record is,
  and a field cannot be sized separately from it.

  The last is a different mistake altogether: a bound that is an expression may
  still only be an *ordinal* one, and `real` is not, so the offer is made and
  declined. }
program DynBoundsErrors(output);
procedure p(m: integer; r: real);
type t = array [1..m] of integer;          { a type-definition }
var  u: record f: array [1..m] of integer  { a field of a record }
     end;
     w: array [1..r] of integer;           { an expression, but not ordinal }
     x: t;
begin
  writeln('unreached ', m:1, x[1]:1, u.f[1]:1, w[1]:1)
end;
begin p(2, 1.0) end.
