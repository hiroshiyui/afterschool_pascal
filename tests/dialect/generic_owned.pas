{ A generic written once for an owned type argument and an ordinary one.

  `take` (AP 6.4.14.6) is the only operation in this language whose
  *applicability* depends on the type it is applied to: an owned pointer and a
  handle have no copy, so a move is the only way one variable comes to hold
  what another held, and every other type has a copy and no move. A generic
  body has to be written before that is known.

  So the two dialect features did not compose. `PasContainer`'s reallocation
  is `dispose(v); v := fresh`, which an owned instantiation refuses because it
  is a copy, and `dispose(v); v := take(fresh)`, which an ordinary one refuses
  because there is nothing to empty -- and the module has both kinds of client
  in this tree (ADR-0323). What was missing is that inside a generic's body
  `take` reads as *move where the type moves*, which is what this program
  compiles twice to show.

  The vector below is `PasContainer`'s, reached under both spellings. The
  chain under it is the rule without a library in the way: one generic
  procedure, two instantiations, and the same source line is a move in the
  first and a copy in the second. }
program generic_owned(output);

import PasContainer;

type
  OVec = owned ^Vec(integer);      { the block owns it; released by leaving }
  PVec = ^Vec(integer);            { §6.4.4's pointer, freed by the program }

{ The rule with nothing else in it. `keep` is a local of the parameter's own
  type, so `take` here is the move for an owned instantiation and the value
  for any other -- and the body cannot tell which, which is the point. }
procedure Rotate(T: type; var a, b: T);
var keep: T;
begin
  keep := take(a);
  a := take(b);
  b := take(keep)
end;

var
  ov: OVec; pv: PVec; i, n: integer;
  x, y: integer;

begin
  { An owned generic container: `new` inside the module, released by leaving
    this block, and nothing here writes a dispose. }
  VecInit(ov, 2);
  for i := 1 to 6 do VecPush(ov, i * i);
  n := 0;
  for i := 1 to VecLen(ov) do n := n + VecGet(integer, ov, i);
  writeln('owned  len ', VecLen(ov):1, ' sum ', n:1);

  { The same module, the same source, an ordinary pointer -- which is what
    `lib/dialect/pasjson.pas` needs and cannot give up: its `JsonChars` lives
    in a variant part, and AP 6.4.14.2 refuses an owned pointer there. }
  VecInit(pv, 2);
  for i := 1 to 6 do VecPush(pv, i * i);
  n := 0;
  for i := 1 to VecLen(pv) do n := n + VecGet(integer, pv, i);
  writeln('plain  len ', VecLen(pv):1, ' sum ', n:1);
  VecFree(pv);

  { And the generic above, over a type that has no move at all. }
  x := 3; y := 7;
  Rotate(x, y);
  writeln('rotate ', x:1, ' ', y:1)
end.
