{ Where 6.2.3.8 b)'s offer is *not* made, and what is said instead (ADR-0113,
  ADR-0127, ADR-0133).

  The clause puts a subrange-bound in the block's commencement where it is
  "closest-contained by ... the block" -- which a variable's own denoter is, and
  which a type-definition is too. Since ADR-0133 a bare subrange is one as well,
  at any depth of arrays and subranges, so what is left refused is every
  position on the way to storage this activation does not size:

  a record's field, because the record's storage is sized where the record is
  and a field cannot be sized separately from it; a set's base type, whose
  extent decides the set's representation; and a file's component, whose size
  the runtime is told once.

  The last is a different mistake altogether: a bound that is an expression may
  still only be an *ordinal* one, and `real` is not, so the offer is made and
  declined. That message is the one ADR-0127 corrected -- what is wrong with a
  real bound is not that it fails to be constant. }
program DynBoundsErrors(output);
procedure p(m: integer; r: real);
type fl = file of 1..m;                    { a file's component }
var  u: record f: 1..m end;                { a field of a record }
     s: set of 1..m;                       { a set's base type }
     w: array [1..r] of integer;           { an expression, but not ordinal }
begin
  writeln('unreached ', m:1, u.f:1, w[1]:1, ord(s = []):1)
end;
begin p(2, 1.0) end.
