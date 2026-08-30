{ AP 6.7.3.10.5's refusals (ADR-0266), one per category and in both of
  AP 6.7.3.10's two activation forms.

  Every one of these is reported at the **call**, which is the whole of what a
  constraint buys. Without it each is refused inside the generic's own source
  by whatever operator the body used -- on a line the caller may never have
  opened -- and ADR-0259's attribution line is the reader's only route back.
  `tests/dialect/generic_errors.pas` still holds that shape for an
  unconstrained generic, which is what the two files read against each other.

  Sema accumulates (ADR-0024), so every refusal below is reported in one run.
  Each is followed by `unknown function` or `unknown procedure`: an
  instantiation that was refused produced no routine, and the activation then
  has nothing to be an activation of. }
program generic_constraint_errors(output);

type
  Point = record x, y: integer end;
  Pair = array [1..2] of integer;

function Sum(Elem: numeric type; a, b: Elem): Elem;
begin
  Sum := a + b
end;

function Span(Elem: ordinal type; lo, hi: Elem): integer;
begin
  Span := ord(hi) - ord(lo)
end;

function Larger(Elem: ordered type; a, b: Elem): Elem;
begin
  if a > b then Larger := a else Larger := b
end;

function Alike(Elem: equatable type; a, b: Elem): boolean;
begin
  Alike := a = b
end;

procedure Ignore(Any: type; Elem: numeric type; x: Any; a: Elem);
begin
  a := a + a
end;

var
  p: Point;
  pr: Pair;
  z: complex;
  f: text;
  ok: boolean;
  i: integer;

begin
  p.x := 0;
  pr[1] := 0;
  z := cmplx(1.0, 0.0);
  i := 0;

  { numeric, with the type written out: the position reported is the argument
    that names it, and there is nothing to say about how it was chosen. }
  p := Sum(Point, p, p);

  { numeric, inferred (AP 6.7.3.10.4): no type is written anywhere in the
    call, so the position reported is the actual that determined `Elem` and
    the message says which one that was. }
  p := Sum(p, p);

  { ordinal. A real is numeric and is not an ordinal-type, which is the pair
    the two categories exist to keep apart. `int64` is refused here for the
    same reason and by AP 6.4.2.6.2's own words. }
  i := Span(2.5, 7.5);

  { ordered. Two records have no ordering, and the second determining
    position is never reached: `Elem` is bound by the first actual and the
    rest is 6.4.6's ordinary business (AP 6.7.3.10.4 NOTE 7). }
  p := Larger(p, p);

  { equatable, written out. 6.8.3.5 gives an array no relational operators at
    all, so `a = b` in the body could never have been legal for one. }
  ok := Alike(Pair, pr, pr);

  { equatable, and a complex *is* equatable -- so this one is accepted, and
    the constraint is not merely refusing everything structured. It is here
    because a category that admitted nothing would pass a corpus of
    refusals. }
  ok := Alike(z, z);

  { A file is refused by `equatable` and would be refused by every other
    category too. It is the case ADR-0266 declined to answer with
    `not IsAffine`: that predicate would have admitted the record and the
    array above, and refused only this. }
  ok := Alike(f, f);

  { A constrained type parameter beside an unconstrained one: `Any` takes the
    record without complaint and `Elem` refuses it, in a procedure-statement
    rather than in an expression. }
  Ignore(Point, Point, p, p);

  writeln(ok, i:1)
end.
