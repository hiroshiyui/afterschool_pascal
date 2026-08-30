{ AP 6.7.3.10.4 (ADR-0254): a generic activation that does not write its type
  arguments, because the other arguments already say what they are.

  `Swap(integer, i, j)` was the only spelling until this clause. The types
  were written at the call even where the call could not have meant anything
  else, which is what made `lib/`'s five `…Or(r, whenBad)` accessors cheaper
  than the one generic that would replace them: `ValueOr(integer, a, 0)` is
  wordier at thirty call sites than `IntOr(a, 0)` is at thirty. This is that
  row answered -- `ValueOr(a, 0)` reads the same as the helper and is the
  generic.

  The rule is a count and one tie-break. A type parameter occupies a position
  in the generic's formal list and none in the produced routine's, so an
  activation writing its types has as many actuals as there are formals and
  one leaving them to be inferred has that many less the type parameters;
  there is at least one type parameter, so the two numbers differ. Where the
  shorter count is written, the question that decides is whether the actual
  standing where the first type parameter would stand *names a type* -- which
  is a question about a name and never about a value, so it cannot be wrong.

  What is pinned here beyond the feature itself: two type parameters in one
  group, and a type parameter written after a value parameter. Both were
  latent defects of the walk this clause rewrote, which matched actuals
  against parameter *groups* rather than against formals. }
program generic_infer(output);

type
  Code = (failed, refused);
  Fallible(T: type) = T ! Code;
  IntFallible = Fallible(integer);
  Short = string(8);
  Row = array [1..4] of integer;

{ The determining position is a schema production, so the binding is read out
  of the tuple `good`'s type was produced with -- the shape a name-only
  unifier gets wrong, because `whenBad` alone would say `string(4)` for the
  `Short` call below. }
function ValueOr(T: type; res: Fallible(T); whenBad: T): T;
begin
  if res.ok then ValueOr := res.val else ValueOr := whenBad
end;

{ Two names in one type-parameter group. Until AP 6.7.3.10.4 the walk took one
  actual for the group and gave both names its type, so `U` was `T`. }
procedure Show(T, U: type; a: T; b: U);
begin
  writeln(a, ' ', b)
end;

{ A type parameter after two value parameters in a group of their own. The old
  walk matched the type group against the second `integer` and complained that
  an argument nobody meant as a type must name one. }
function Third(a, b: integer; T: type; x: T): T;
begin
  if a < b then Third := x else Third := x
end;

var
  i, j: integer;

{ ADR-0125's slice is a parameter-form too, and its component determines. }
function Total(T: type; protected var xs: array of T): integer;
var k, n: integer;
begin
  n := 0;
  for k := 1 to length(xs) do n := n + ord(xs[k]);
  Total := n
end;

procedure Swap(T: type; var a, b: T);
{ Not `t`: 6.1.3 folds case, so `t` and `T` are one identifier and the local
  would shadow the type parameter in its own declaration. }
var held: T;
begin
  held := a; a := b; b := held
end;

var
  good, bad_: IntFallible;
  ch: Fallible(char);
  st: Fallible(Short);
  r: Row;
  c: char;

begin
  good := 7;
  bad_ := failed;
  ch := 'x';
  st := refused;
  r[1] := 10; r[2] := 20; r[3] := 30; r[4] := 40;

  { Inferred, through the production: `good` is a Fallible(integer), so T is
    integer and `0` is an ordinary actual of it. }
  writeln(ValueOr(good, 0):1, ' ', ValueOr(bad_, -1):1);

  { The case a name-only unifier gets wrong. `st` says string(8); `'none'` is
    four characters, and it is *assignment-compatible* with string(8) rather
    than a second opinion about what T is. }
  writeln(ValueOr(ch, '?'), ' ', ValueOr(st, 'none'));

  { The written form still works, and names the same tuple -- so it is the
    same instantiation and not a second one. }
  writeln(ValueOr(integer, good, 0):1, ' ', ValueOr(good, 0):1);

  Show(1, 'a');
  Show(integer, char, 2, 'b');

  writeln(Third(1, 2, 'c'), ' ', Third(1, 2, char, 'd'));

  writeln(Total(r[1..4]):1);

  i := 3; j := 4;
  Swap(i, j);
  writeln(i:1, ' ', j:1);
  c := 'p';
  Swap(c, c);
  writeln(c)
end.
