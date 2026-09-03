{ AP 6.4.14: what an owned pointer refuses, and each refusal's reason.

  An owned pointer is affine (ADR-0151, ADR-0181): it has the file variable's
  refusals through the same predicate -- ContainsFile, which predicate-callers
  sweeps -- and four of its own, which are the ones written out here. Sema
  accumulates, so one file.

  The messages are the affine family's own words rather than the file's: the
  shared predicate answers yes for all three kinds, and until ADR-0181 every
  caller said "it contains a file" about whatever it found. }
program owned_errors(output);
type
  NodePtr = owned ^Node;
  Node = record key: integer; next: NodePtr end;
  Sch(n: integer) = array [1..n] of integer;
  { 6.4.14.2: releasing the variable would have to walk it, and a schema's
    lengths are read from a descriptor a frame holds }
  SchPtr = owned ^Sch;
  { and again with the schema named *later*, which is the other path: a domain
    whose name is not yet defined pends, and the refusal has to be made a
    second time where the pending list is drained }
  LatePtr = owned ^Late;
  Late(n: integer) = array [1..n] of integer;
  Sel = 1..2;
  { 6.4.14.2: two arms share one slot, and there is no answer to which arm's
    pointer is to be disposed }
  Variant = record case k: Sel of 1: (a: NodePtr); 2: (b: integer) end;
  Plain = ^Node;
var
  p, q: NodePtr; z: Plain; v: Variant;
{ 6.4.14.3: a result is a value, and the variable that would release it is the
  one a result has not got }
function Answer: NodePtr;
begin end;
{ 6.4.14.3: a value parameter is a copy }
procedure ByValue(n: NodePtr);
begin end;
procedure Lend(var n: NodePtr);
begin end;
{ 6.4.14.5: an owned-pointer-type is a new-type, so this formal's own denoter
  is a type of its own and no NodePtr will fit it }
procedure LendAnon(var n: owned ^Node);
begin end;
begin
  new(p);
  { 6.4.14.3: no copy, in either direction, and not even to an ordinary
    pointer -- there is no borrow in this clause }
  q := p;
  z := p;
  p := z;
  { 6.4.14.4: nil and nothing else }
  if p = q then writeln('same');
  if p < nil then writeln('less');
  { the second diagnostic on this line -- "is nodeptr, but the value is
    nodeptr" -- is not this clause's. A refused value parameter keeps its
    declared type, so the argument check then compares that type with itself
    and prints both; `procedure BV(x: Rec)` over a record holding a `text`
    did the same under `--std=extended`, and has since long before ADR-0181. }
  ByValue(p);
  { 6.4.14.5: two separately written denoters are two types, so a program that
    lends one declares a name for it -- Lend takes NodePtr and is legal }
  Lend(p);
  LendAnon(p);
  { AP 6.4.14.6, and the value a reader tries next: a handle takes `h := nil`
    as its release (AP 6.4.12.2) and an owned pointer does not, because it has
    `dispose` and a handle has nothing else. The message names it (ADR-0307).
    Written after `new(p)` so the variable really does identify storage. }
  p := nil;
  v.k := 2
end.
