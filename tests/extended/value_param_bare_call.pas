{ §6.8.5 makes the actual-parameter-list of a function-designator optional, so
  a parameterless function written as a bare identifier *is* the call -- and
  §6.7.3.2 makes a value parameter's actual an expression, which a call is. So
  `take(mk)` is legal wherever `take(mk(0))` is.

  It was refused for a value parameter of a structured type, and only there:
  `q := mk` copied from the same address, `mk.x` selected from it, and the
  parenthesised spelling was accepted. The check knew about an nkCall and a
  bare name is an nkVar with the call decided by Sema -- the husk of ADR-0044
  seen from the side that forgot to ask (ADR-0179).

  Extended Pascal only, and not because of a mode: §6.6.2 of ISO 7185 gives a
  function a simple-type or a pointer-type result, so no ISO 7185 program has
  a structured result to pass. }
program value_param_bare_call(output);

type
  Point = record x, y: integer end;
  Vector = array [1..3] of integer;
  Line = string(8);

var q: Point;

{ each of these is parameterless, so its bare name is the whole call }
function origin = r: Point;
begin
  r.x := 3;
  r.y := 4
end;

function counted = r: Vector;
var k: integer;
begin
  for k := 1 to 3 do r[k] := k * k
end;

function greeting = r: Line;
begin
  r := 'hello'
end;

{ ...and one with a parameter, so that the two spellings of one construct are
  compared rather than only one of them tested }
function scaled(k: integer) = r: Point;
begin
  r.x := 3 * k;
  r.y := 4 * k
end;

procedure takePoint(p: Point);
begin
  writeln('point ', p.x:1, ' ', p.y:1)
end;

procedure takeVector(v: Vector);
begin
  writeln('vector ', v[1]:1, ' ', v[2]:1, ' ', v[3]:1)
end;

procedure takeLine(s: Line);
begin
  writeln('line ', s)
end;

{ a value parameter is the callee's own variable (§6.7.3.2), and the prologue
  copy that makes it one is reached by this spelling as by the other }
procedure writesToIt(p: Point);
begin
  p.x := 99;
  writeln('inside ', p.x:1, ' ', p.y:1)
end;

begin
  takePoint(scaled(1));      { the spelling that always worked }
  takePoint(origin);         { the one that did not }
  takeVector(counted);
  takeLine(greeting);

  writesToIt(origin);
  q := origin;
  writeln('caller ', q.x:1, ' ', q.y:1);

  { the other positions the same call already stood in }
  writeln('field ', origin.x:1);
  writeln('index ', counted[2]:1)
end.
