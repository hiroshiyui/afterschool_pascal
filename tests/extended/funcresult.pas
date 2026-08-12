{ ISO/IEC 10206:1991 §6.7.2. Two halves of one clause, and they arrive
  together because neither is much use alone.

  The first is what a function may *return*. ISO 7185 §6.6.2 lists what is
  allowed — a simple type or a pointer — and §6.7.2 replaces the list with what
  is refused: a file, something containing a file, and a bindable type. So a
  record, an array and a set are all results now.

  The second is the result-variable-specification, `= identifier` between the
  parameters and the result type. Without one the only way to write the result
  is `f := e`, because §6.8.2.2 makes every *read* of `f` a recursive call — so
  a structured result could be assigned whole and never built a field at a
  time. `mk` below is the shape that needs it.

  What makes the feature small is that the result travels by the address the
  *caller* supplies: the callee's activation record dies at the return, so the
  storage cannot be there. Each call site keeps a hidden frame slot for it, and
  the callee binds the incoming address exactly as a `var` parameter does. }
program FuncResult(output);
type
  point  = record x, y: integer end;
  vec3   = array [1..3] of integer;
  digits = set of 0..9;

var p, q: point; v: vec3; d: digits; i: integer;

{ A result variable is an ordinary variable of the block, so the result is
  built a field at a time. }
function mk(a, b: integer) = r: point;
begin r.x := a; r.y := b end;

{ ...and a component at a time. }
function scale(s: integer) = out: vec3;
var j: integer;
begin for j := 1 to 3 do out[j] := j * s end;

{ A set is a *value* (ADR-0028) and returns in a register like a real, so it
  needs none of the by-address machinery — but §6.6.2 refused it and §6.7.2
  does not, which is the whole of what changed for this one. }
function evens = e: digits;
var j: integer;
begin e := []; for j := 0 to 9 do if not odd(j) then e := e + [j] end;

{ The result of one call feeding another: `twice` writes into its own caller's
  storage, and the inner `mk` writes into a slot of `twice`'s frame. }
function twice(a, b: integer): point;
begin twice := mk(a * 2, b * 2) end;

{ A result variable on a *simple* type, where nothing about the convention
  changes: the point is only that the body may read it back, which a function
  identifier can never be made to do. }
function total(w: vec3) = n: integer;
var j: integer;
begin n := 0; for j := 1 to 3 do n := n + w[j] end;

{ Recursion, where each activation brings its own frame and so its own call
  slots — the reason nothing had to be said about it. }
function chain(k: integer) = r: point;
begin
  if k = 0 then begin r.x := 0; r.y := 0 end
  else begin r := chain(k - 1); r.x := r.x + k; r.y := r.y + k * k end
end;

{ A functional parameter whose result lives in memory. An indirect call is
  the one place a caller states the whole signature rather than naming a
  function the module already carries, so the hidden result address has to
  appear there too — and this is the only shape that says so. }
function apply(function g(a, b: integer): point; k: integer) = r: point;
begin r := g(k, k + 1) end;

begin
  p := mk(3, 4);
  writeln('record ', p.x:1, ' ', p.y:1);

  q := twice(3, 4);
  writeln('nested ', q.x:1, ' ', q.y:1);

  v := scale(10);
  write('array ');
  for i := 1 to 3 do write(' ', v[i]:1);
  writeln;

  writeln('simple ', total(v):1);

  d := evens;
  write('set   ');
  for i := 0 to 9 do if i in d then write(' ', i:1);
  writeln;

  q := chain(4);
  writeln('recurs ', q.x:1, ' ', q.y:1);

  { A structured result is a value like any other: it can be assigned to a
    variable, and a whole-variable copy is what carries it. }
  p := mk(1, 2);
  q := p;
  writeln('copy   ', q.x:1, ' ', q.y:1);

  q := apply(mk, 5);
  writeln('indir  ', q.x:1, ' ', q.y:1)
end.
