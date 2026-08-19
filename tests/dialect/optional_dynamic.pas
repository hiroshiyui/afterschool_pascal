{ An optional holds its T rather than pointing at it, so a bound inside that T
  is a bound inside the optional -- and ADR-0045's descriptor can describe a
  record only when the dynamically-sized part is its *last* field.

  This is the arm the `kind-exhaustive` gate cannot judge. That check asks
  whether every type kind is *named* by every case-statement over one, which is
  what turns a crash into a review; it cannot ask whether the answer is right.
  `tyOptional: StaticThroughout := true` would satisfy it, and would let the
  schema below through to generate a field offset nothing can compute. This
  case is what says so. }
program optional_dynamic(output);

type
  Bad(n: integer) = record
    { Dynamic, because the optional's T is, and not last. }
    head: ?array [1..n] of real;
    tail: integer
  end;

{ A schematic formal is what asks: the type is produced with no tuple, so the
  descriptor has to be able to describe it. }
procedure takes(var b: Bad);
begin
end;

begin
end.
