{ 6.2.3.8 b) at a type-definition (ADR-0127).

  The clause evaluates "each actual-discriminant-part or subrange-bound not
  contained by a schema-definition and closest-contained by ... the block" at
  the commencement of that block's activation. A type-definition is contained
  by the block, so both spellings are legal there -- a bare bound and a schema
  production -- and ADR-0113 took only the variable half of the same sentence.

  What makes it a different decision rather than the rest of the same one is
  who owns the descriptor. A variable's belongs to the variable; a type's
  belongs to the *block*, because the clause evaluates the bound **once**
  however many variables of the type the block goes on to declare, and 6.4.1
  makes them one type. So `a := b` between two of them is the assignment
  6.4.1 says it is, and `witness` below is what shows the single evaluation:
  a bound that counts its own calls is called once for two variables. }
program DynBoundsType(output);

var calls: integer;

function four: integer;
begin
  four := 4
end;

function witness: integer;
begin
  calls := calls + 1;
  witness := 3
end;

type
  { the program-block is a block too, and 6.2.2.9 with ADR-0100's interleaving
    is what makes a function declared above it a well-defined bound }
  global = array [1..four] of integer;

var g: global;

type vec(n: integer) = array [1..n] of integer;

{ A nested procedure takes one by name. The bounds are in the enclosing
  block's frame, so the callee reaches them by the walk up the static chain
  that every enclosing variable is reached by -- there is no tuple to pass. }
procedure outer(m: integer);
type
  row = array [1..m] of integer;
  col = vec(m + 1);
var a, b: row;
    c: col;
    i: integer;

  procedure fill(var r: row; base: integer);
  var k: integer;
  begin
    for k := 1 to m do
      r[k] := base + k
  end;

begin
  fill(a, 10);
  for i := 1 to m do
    b[i] := 0;
  { one type, so this is a whole-variable assignment and not a mismatch }
  b := a;
  for i := 1 to m + 1 do
    c[i] := i * i;
  write('m=', m:1, ' b:');
  for i := 1 to m do
    write(' ', b[i]:1);
  write(' c:');
  for i := 1 to m + 1 do
    write(' ', c[i]:1);
  writeln;
  { every activation evaluates its own, so the inner one is a different extent }
  if m > 2 then outer(m - 1)
end;

{ two variables of one type, and the bound is evaluated once for the type
  rather than once for each of them }
procedure counted;
type ct = array [1..witness] of integer;
var p, q: ct;
    k: integer;
begin
  for k := 1 to 3 do
    p[k] := k;
  q := p;
  writeln('calls=', calls:1, ' q=', q[3]:1)
end;

var h: global;
    i: integer;

begin
  calls := 0;
  for i := 1 to 4 do begin
    g[i] := i;
    h[i] := 10 * i
  end;
  writeln('g=', g[4]:1, ' h=', h[4]:1);
  counted;
  counted;
  outer(4)
end.
