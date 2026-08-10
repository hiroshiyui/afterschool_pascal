{ Procedural and functional parameters (ISO 7185 6.6.3.1). }
program ProcParam(output);

type
  vector = array [1..5] of integer;

var
  v: vector;
  i: integer;

{ A functional parameter: `apply` knows nothing about `f` but its heading. }
procedure Apply(var a: vector; function f(x: integer): integer);
var
  k: integer;
begin
  for k := 1 to 5 do
    a[k] := f(a[k])
end;

function Double(x: integer): integer;
begin
  Double := x * 2
end;

function Negate(x: integer): integer;
begin
  Negate := -x
end;

{ A procedural parameter, and one that is passed straight on to another
  procedure: the pair travels unchanged, so `Twice` runs `p` in its own
  scope rather than in Twice's. }
procedure Twice(procedure p(n: integer); n: integer);
begin
  p(n);
  p(n)
end;

procedure Show(n: integer);
begin
  writeln('show ', n:1)
end;

procedure Relay(procedure p(n: integer); n: integer);
begin
  Twice(p, n)
end;

{ The case that distinguishes a correct implementation from one that passes
  the caller's frame: `Bump` reads `base`, a local of the *invocation of
  Outer that declared it*, while running inside Apply — which has no such
  variable and is not nested in Outer at all. }
procedure Outer(base: integer);

  function Bump(x: integer): integer;
  begin
    Bump := x + base
  end;

begin
  Apply(v, Bump)
end;

{ Nested one level deeper again, and passed out through two procedures. }
procedure Counter;
var
  seen: integer;

  procedure Note(n: integer);
  begin
    seen := seen + n;
    writeln('note ', n:1, ' total ', seen:1)
  end;

begin
  seen := 0;
  Relay(Note, 3);
  writeln('counter ', seen:1)
end;

procedure Reset5;
var
  k: integer;
begin
  for k := 1 to 5 do
    v[k] := k
end;

function CallIt(function f(x: integer): integer; x: integer): integer;
begin
  CallIt := f(x)
end;

{ The counterpart of tests/nesting.pas: a nested function passed out of a
  *recursive* procedure must see the locals of the invocation that passed it,
  not of the deepest one on the stack. The recursion unwinds after the call,
  so each level prints its own depth. }
procedure Rec(depth: integer);

  function Mine(x: integer): integer;
  begin
    Mine := x + depth
  end;

begin
  if depth > 0 then
    Rec(depth - 1);
  writeln('rec ', depth:1, ' ', CallIt(Mine, 0):1)
end;

{ A procedural parameter of a procedural parameter -- the recursion in the
  grammar, and the recursion in the congruity rule. }
procedure Chain(procedure outer(procedure inner(n: integer); n: integer));
begin
  outer(Show, 9)
end;

begin
  Reset5;
  Apply(v, Double);
  for i := 1 to 5 do
    write(v[i]:3);
  writeln;

  Apply(v, Negate);
  for i := 1 to 5 do
    write(v[i]:3);
  writeln;

  Reset5;
  Outer(100);
  for i := 1 to 5 do
    write(v[i]:5);
  writeln;

  { A second invocation of Outer: Bump must see *this* base, not the last. }
  Reset5;
  Outer(-1);
  for i := 1 to 5 do
    write(v[i]:3);
  writeln;

  Twice(Show, 7);
  Counter;
  Rec(2);
  Chain(Twice)
end.
