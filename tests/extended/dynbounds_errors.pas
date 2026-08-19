{ Where 6.2.3.8 b)'s offer is *not* made, and what is said instead (ADR-0113,
  ADR-0127, ADR-0133, ADR-0134).

  The clause puts a subrange-bound in the block's commencement where it is
  "closest-contained by ... the block" -- which a variable's own denoter is, a
  type-definition is, and a record's or a file's denoter is too, a record being
  no kind of block. So the offer now reaches through both of those, and what is
  refused is not a *position* but a consequence: a field or a component whose
  **size** the bound decides.

  A field's storage is laid out where the record is, and a field after a
  dynamically sized one sits at an offset nothing can compute (ADR-0045); a
  file is told one component size when it is prepared. A *subrange* field and a
  subrange component are the cases that work, and work for the reason ADR-0133
  gives -- a subrange's storage is its host's whatever its bounds are, so it
  sizes nothing. `dynbounds_subrange.pas` writes both.

  A set is the one container still refused outright. Every set here is one
  256-bit word whose base type must have its values in 0..255 (ADR-0028), and
  a bound the block evaluates is a bound nothing can check that against before
  the program runs.

  The last is a different mistake altogether: a bound that is an expression may
  still only be an *ordinal* one, and `real` is not, so the offer is made and
  declined. That message is the one ADR-0127 corrected -- what is wrong with a
  real bound is not that it fails to be constant. }
program DynBoundsErrors(output);
procedure p(m: integer; r: real);
type fa = file of array [1..m] of integer;  { a component with a size }
var  u: record f: array [1..m] of integer   { a field with a size }
        end;
     s: set of 1..m;                        { a set's base type }
     w: array [1..r] of integer;            { an expression, but not ordinal }
begin
  writeln('unreached ', m:1, u.f[1]:1, w[1]:1, ord(s = []):1)
end;
begin p(2, 1.0) end.
