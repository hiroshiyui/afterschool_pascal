{ A routine generic over a *fallible* type, which the roadmap said could not
  be written and can (ADR-0211, AP 6.4.13, AP 6.7.3.5).

  The language server's ergonomic finding was that `lib/` carries one
  `…Or(r, whenBad)` accessor per result type -- five of them are genuinely
  `T ! ErrorCode -> T` -- and that reading was that a routine generic over the
  fallible type could not be written. It can. What cannot is the *anonymous*
  form: a heading saying `res: T ! Code` produces a new type-denoter, and
  6.4.1 makes each denoter that is not a type name denote a type of its own,
  so it never matches the caller's. A **schema** is the answer, because 6.4.7
  interns a production per tuple (ADR-0039) -- so `Fallible(integer)` written
  in two places is one type.

  What this case pins is therefore two things at once: that the generic works,
  and *why the library does not use it*. Compare the two call forms below.
  `ValueOr(integer, a, 0)` names a type the argument already knows, where
  `IntOr(a, 0)` does not -- so collapsing the five helpers into one generic
  would make thirty call sites wordier to make one library smaller. The
  helpers are not a workaround for a missing generic. They are a workaround
  for missing **inference**, which is a separate row and now has a caller. }
program generic_fallible(output);

type
  Code = (failed, refused);
  { The schema is what makes two productions one type. }
  Fallible(T: type) = T ! Code;
  { An ordinary name for a production, exactly as `lib/` names its result
    types today -- so this is the shape a library would take, not a new one. }
  IntFallible = Fallible(integer);
  { A type discriminant takes a type *name*, so a capacity-bearing denoter
    needs one of its own before it can be given to a schema. }
  Short = string(8);

function ValueOr(T: type; res: Fallible(T); whenBad: T): T;
begin
  if res.ok then ValueOr := res.val else ValueOr := whenBad
end;

{ The per-type helper the library actually has, for the comparison. }
function IntOr(res: IntFallible; whenBad: integer): integer;
begin
  if res.ok then IntOr := res.val else IntOr := whenBad
end;

var
  good, bad_: IntFallible;
  ch: Fallible(char);
  st: Fallible(Short);

begin
  good := 7;
  bad_ := failed;
  ch := 'x';
  st := refused;

  { One routine, four types, two of them structured. }
  writeln(ValueOr(integer, good, 0):1, ' ', ValueOr(integer, bad_, -1):1);
  writeln(ValueOr(char, ch, '?'), ' ', ValueOr(Short, st, 'none'));

  { A named production and its schema are the same type, so the generic and
    the hand-written helper take the same argument. }
  writeln(IntOr(good, 0):1, ' ', ValueOr(integer, good, 0):1)
end.
