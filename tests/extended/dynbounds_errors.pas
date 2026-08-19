{ Where 6.2.3.8 b)'s offer is *not* made, and what is said instead (ADR-0113,
  ADR-0127).

  The clause puts a subrange-bound in the block's commencement where it is
  "closest-contained by ... the block" -- which a variable's own denoter is,
  and which a type-definition is too (ADR-0127). What is left refused is every
  position that is on the way to storage this activation does not size.

  A field's denoter is not one: the record's storage is sized where the record
  is, and a field cannot be sized separately from it.

  A *bare* subrange is not one either, and that one is the newer answer. An
  array's index-type is the single position where a bound with a discriminant
  in it does any work: the subscript check reads it out of the descriptor. A
  subrange written anywhere else -- as a variable's whole type, as a
  type-definition, as an array's component -- exists to be range-checked at a
  store, and that check compares against the two numbers on the type rather
  than against a descriptor. Left accepted, `a[1] := 2` over
  `array [1..m] of 1..m` trapped with the upper bound reading zero: a legal
  program stopped by a check whose bound had never been read from anywhere.

  The last is a different mistake altogether: a bound that is an expression may
  still only be an *ordinal* one, and `real` is not, so the offer is made and
  declined. }
program DynBoundsErrors(output);
procedure p(m: integer; r: real);
type t = 1..m;                             { a bare subrange, as a type }
var  u: record f: array [1..m] of integer  { a field of a record }
     end;
     v: 1..m;                              { a bare subrange, as a variable }
     w: array [1..r] of integer;           { an expression, but not ordinal }
     x: array [1..m] of 1..m;              { a component, not an index-type }
     y: t;
begin
  writeln('unreached ', m:1, u.f[1]:1, v:1, w[1]:1, x[1]:1, y:1)
end;
begin p(2, 1.0) end.
