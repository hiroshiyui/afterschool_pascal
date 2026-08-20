{ A wide literal in a constant position, which is the half int64_types.pas
  does not reach.

  That file writes the type name and `maxint64` in every position that needs
  the compiler to hold a value, and both of those *fold*: `maxint64` is a
  constant-identifier and folds to a symbol whose type is int64, so each
  position reports its own ordinal message. A literal above `maxint` is a
  different node, and until ADR-0135 it reached a case-statement in the folder
  with no arm for it -- which is not a wrong answer but a **stopped compiler**
  (6.8.3.5's error, ADR-0018), so nothing here could hold a golden for it.

  Every gate was green. No case in this corpus had ever written a wide literal
  where a constant was required, and both conformance modes reject such a
  literal in the lexis, so nothing outside the dialect could reach it either.
  It was found by probing a requirement while writing the specification, which
  is AP 5.5 a).

  Two messages appear below and the split is the point. Where the position
  wants an *ordinal*, the message it has always given is already right -- an
  int64 is not one (AP 6.4.2.6.2) and not one word was written for this file.
  A constant-definition wants no such thing, a constant being allowed to be
  real, so the generic "not a compile-time constant" would have been a plain
  untruth about a literal: 5000000000 is a compile-time constant in any
  language that can hold it. That one gets a message of its own. }
program Int64Const(output);
const
  c1 = 5000000000;               { 6.3: a constant-definition }
  c2 = 5000000000 + 1;           { 6.8.2: an operand of a constant-expression }
  c3 = -5000000000;              { the sign does not make it foldable }
type
  t1 = 1..5000000000;            { 6.4.2.4: a bound is an ordinal constant }
var
  a: array [1..5000000000] of integer;   { 6.4.3.2: the index-type }
  s: set of 1..5000000000;               { 6.4.3.5: the base-type }
  n: integer;
begin
  n := 1;
  case n of
    5000000000: writeln('unreached')     { 6.9.3.5: a case-constant }
  end
end.
