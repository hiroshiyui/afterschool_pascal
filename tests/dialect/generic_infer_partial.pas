{ AP 6.7.3.10.4 (ADR-0304): an activation may write *some* of its type
  arguments and leave the rest to be inferred.

  ADR-0254 admitted two forms, all and none, and that left one shape with no
  short spelling: a generic one of whose type parameters stands only in the
  result. 6.7.1 makes a result-type a type-name and not an actual, so nothing
  can determine it -- and until this clause, writing it meant writing every
  other one too, however plainly the arguments said what they were.
  `VecGet(JsonChars, char, b, i)` in `lib/dialect/pasjson.pas` was the
  standing case and is now `VecGet(char, b, i)`.

  The written type arguments are a **prefix** of the type parameters, so the
  arity says how many there are and the list never has to be read to find out
  where the types stopped. A generic therefore writes its undeterminable type
  parameters first, which is what `VecGet` and `MapKeyAt` now do.

  What is pinned here: the prefix form at k = 1 of 2 and k = 2 of 3; a type
  parameter standing after value parameters, so that the position of the first
  *omitted* one is not the position of the first type parameter; the two forms
  naming one instantiation, which 6.7.3.10.2 makes the tuple's business; and a
  written type argument being the first determining position, so a later
  actual cannot redetermine it. }
program generic_infer_partial(output);

type
  Small = string(8);
  Row = array [1..4] of integer;

{ `Elem` stands only in the result: `VecGet`'s shape, with an array in place
  of the container. `Cont` is said by `v`, so one argument is written and one
  inferred. }
function ItemAt(Elem: type; Cont: type; protected var v: Cont;
                i: integer): Elem;
begin
  ItemAt := v[i]
end;

{ Three type parameters: `Res` is undeterminable, `A` and `B` are said by the
  two values. Written at k = 1, and again at k = 3 to show the same tuple. }
function Combine(Res: type; A: type; B: type; x: A; y: B): Res;
begin
  Combine := 0
end;

{ The type parameter stands *after* a value parameter, so the position the
  tie-break asks about is the third and not the first. `n` is an ordinary
  actual before the types begin. }
function Tagged(n: integer; Tag: type; Val: type; t: Tag; v: Val): integer;
begin
  Tagged := n + ord(t) + 1
end;

{ A written type argument binds before anything is read off an actual, so
  `whenBad` is judged against it rather than determining it. `Held(real, 2,
  65)` writes `real` and hands it an integer default: were the actual allowed
  to speak, `T` would be integer and the `:6:2` below would not compile. }
function Held(T: type; U: type; whenBad: T; n: U): T;
begin
  Held := whenBad
end;

var
  r: Row;
  s: Small;
  i, k: integer;

begin
  r[1] := 10; r[2] := 20; r[3] := 30; r[4] := 40;
  s := 'abcdefgh';

  { One type argument written, one inferred from `r`. }
  writeln('item  ', ItemAt(integer, r, 3):1);

  { The same generic over a different container, whose element is a char. }
  writeln('char  ', ItemAt(char, s, 2));

  { k = 1 of 3, then the written form of the same activation. Both name the
    tuple (integer, char, Small), so 6.7.3.10.2 translates the body once and
    the two calls reach one produced routine. }
  i := Combine(integer, 'q', s);
  k := Combine(integer, char, Small, 'q', s);
  writeln('same  ', (i = k):5);

  { The first omitted type parameter stands third among the formals, so the
    tie-break does not ask about the first actual. `Val` is inferred from 0. }
  writeln('after ', Tagged(5, char, 'a', 0):1);

  writeln('held  ', Held(real, 2, 65):6:2)
end.
