{ --dump-uses: every applied occurrence in this source and the defining-point
  it resolved to (ADR-0246). It is the compiler's answer to go-to-definition
  and to hover, and this case is the one that reaches every word the `kind`
  field can hold -- twelve of them, one per symKind, which is what stops a
  constant added to that enumeration from being reported as nothing.

  Read the golden as three columns. The first three numbers locate the *use*
  in this file; the next three locate its declaration, and a `0` line there
  means the name has no defining-point a programmer wrote -- `integer` and
  `text` are required identifiers (6.2.2.10), declared in a scope enclosing
  the program. The last two fields are what a hover shows.

  Every use here is deliberate. The declarations are *not* the subject: a
  declaration is what --dump-symbols answers, and this dump reports nothing
  about a name until something applies it. }
program uses(output);

const limit = 4;

type
  colour = (red, green, blue);
  point = record x, y: integer end;
  { A variant part, so a field reached through 6.4.3.3's arm path is reported
    the same way one in the fixed part is -- the position is the field's own
    either way. The labels cover the tag-type exactly, which ADR-0096 requires
    and is why `sides` is a named subrange: 6.4.3.3 makes the tag a
    *type-identifier*, and `integer` would leave values no arm names. }
  sides = 1..2;
  shape = record
    span: integer;
    case kind: sides of
      1: (side: integer);
      2: (base, high: integer)
  end;
  vec(cap: integer) = array [1..cap] of integer;
  chooser = ^colour;

var
  total: integer;
  here: point;
  shade: colour;
  which: chooser;
  three: vec(3);
  box: shape;

{ A value-parameter, a variable-parameter and a procedural-parameter in one
  heading, so all three of 6.7.3.1's spellings are applied somewhere. }
function combine(n: integer; var acc: integer;
                 function pick(k: integer): integer): integer;
begin
  acc := acc + pick(n);
  combine := acc
end;

function twice(k: integer): integer;
begin
  twice := k + k
end;

{ 6.4.7's schema, applied as a formal type: `cap` is the discriminant and
  reading it inside is what puts `discriminant` in the golden. }
procedure widen(var v: vec);
var i: integer;
begin
  for i := 1 to v.cap do
    v[i] := v[i] + limit
end;

procedure show(p: point; c: colour);
begin
  writeln(p.x + p.y, ord(c):3)
end;

begin
  total := 0;
  here.x := 1;
  here.y := 2;
  shade := green;
  which := nil;
  three[1] := 7;
  three[2] := 8;
  three[3] := 9;
  widen(three);
  { 6.4.7's discriminant-identifier both ways round. `three` has a tuple, so
    `cap` is folded to 3 here and the schema's formal is what a reader is sent
    to; `v.cap` inside widen has none, its value arriving with the actual, so
    the occurrence denotes the binding that reads the descriptor. The two are
    different symbols and the same defining-point. }
  total := total + three.cap;
  box.kind := 1;
  box.side := 4;
  { 6.8.3.10's with-statement: a field-identifier written bare. The
    defining-point a reader wants is the *field*, not the with-statement that
    gave it a nearer one -- the binding is a hidden frame variable holding an
    address and knows neither position (ADR-0247). }
  with here do begin
    x := x + 1;
    total := total + x + y
  end;
  total := combine(limit, total, twice);
  show(here, shade);
  writeln(total, three[1]:4, box.span:3)
end.
