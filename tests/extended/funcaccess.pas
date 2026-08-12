{ ISO/IEC 10206:1991 §6.8.6. A function-access is a function-designator with
  selectors on it: `mk(7, 8).y` reads a field of a result without naming a
  variable to hold it first. ISO 7185 §6.6.2 made every result a simple type or
  a pointer, so there was nothing to select from and the clause had no work to
  do; ADR-0055 gave results records, arrays and sets, and this is what that
  unlocked.

  The feature is a parser change and nothing else. A result that lives in
  memory already travels in storage the *caller* supplies (ADR-0055), so a call
  in that position already yields an address — `CodeGen::emitAddress` has had a
  `case NK::Call` since ADR-0052 built `binding(f)` in a frame slot. Sema was
  told nothing at all.

  What keeps it honest is §6.8.6's NOTE: "a function-access is not equivalent
  to a variable-access. For example, a function-access may not be used as an
  actual variable parameter or as the record-variable in a with-statement."
  `Sema::isDesignator` already answered `false` for a call, and every
  restriction the NOTE names is a call site of it — so the refusals in
  `funcaccess_errors.pas` needed no code either. }
program FuncAccess(output);
type
  point = record x, y: integer end;
  vec3  = array [1..3] of integer;
  line  = record a, b: point end;
  points = array [1..2] of point;
  pp    = ^point;
  colour = (red, green, blue);
  shades = set of colour;

var i: integer; g: pp; c: colour;

function mk(a, b: integer) = r: point;
begin r.x := a; r.y := b end;

function scale(s: integer) = out: vec3;
var j: integer;
begin for j := 1 to 3 do out[j] := j * s end;

{ A record of records, so a selector chain has more than one link. }
function seg(k: integer) = l: line;
begin l.a := mk(k, k + 1); l.b := mk(k * 10, k * 20) end;

{ An array of records: the two selector kinds in one access. The result type is
  a type-*name* — §6.7.2 asks for one, which is also what guarantees the
  caller can size the slot (ADR-0055). }
function pair(k: integer) = ps: points;
begin ps[1] := mk(k, 0); ps[2] := mk(0, k) end;

{ §6.8.6.4's pointer-function. This one is the odd member of the family: a
  function-identified-variable *is* a variable-access (§6.5.1), because what a
  pointer points at is a variable however the pointer was obtained. So it is
  the only function-access that may be assigned to. }
function alloc(a: integer): pp;
var t: pp;
begin new(t); t^.x := a; t^.y := a * 2; alloc := t end;

{ A set result — a value, not memory (ADR-0028), so `in` reaches it without any
  of the by-address machinery. }
function warm = s: shades;
begin s := [red, green] end;

begin
  { §6.8.6.3, a record-function-access. }
  writeln('field  ', mk(7, 8).x:1, ' ', mk(7, 8).y:1);

  { §6.8.6.2, an indexed-function-access. }
  writeln('index  ', scale(10)[2]:1);
  write('walk   ');
  for i := 1 to 3 do write(' ', scale(2)[i]:1);
  writeln;

  { A chain: the base of a selector may itself be a selection. }
  writeln('chain  ', seg(5).b.y:1, ' ', seg(5).a.x:1);

  { Both kinds at once, and the abbreviated `[i, j]` form is a subscript
    spine like any other — `pair(k)[i]` is a record, so `.y` follows. }
  writeln('mixed  ', pair(9)[1].x:1, ' ', pair(9)[2].y:1);

  { §6.8.6.4. Reading through the pointer, then writing through it — the one
    function-access that is a variable. The written variable is unreachable
    afterwards, which the standard permits and says nothing about. }
  writeln('deref  ', alloc(6)^.y:1);
  alloc(3)^.x := 99;
  { A nested argument list, because deciding that a statement is this rather
    than a procedure-statement means scanning to the *matching* `)`. A scan
    that stopped at the first one would read `sqr(2)` as the whole call and find
    no `^` after it, and this statement would become a procedure call of
    `alloc`. }
  alloc(sqr(2))^.y := 7;
  g := alloc(4);
  writeln('ptrvar ', g^.x:1, ' ', g^.y:1);

  { A set result needs no selector to be useful; it is here because §6.7.2
    admits it and §6.8.6 does not have to. }
  write('set    ');
  for c := red to blue do if c in warm then write(' ', ord(c):1);
  writeln;

  { A function-access is an expression, so it composes: as an argument, in
    arithmetic, and as the whole right-hand side of an assignment. }
  writeln('expr   ', (mk(2, 3).x + scale(4)[3]):1);
  i := seg(1).b.x;
  writeln('assign ', i:1)
end.
