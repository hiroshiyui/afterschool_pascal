{ The diagnostics of procedural and functional parameters (ISO 7185 6.6.3.1,
  6.6.3.6, 6.6.3.7). Sema accumulates, so one file carries all of them. }
program procparams(output);
type
  vector = array [1..3] of integer;
var
  n: integer;
  v: vector;

procedure Show(x: integer);
begin
  writeln(x:1)
end;

function Twice(x: integer): integer;
begin
  Twice := x * 2
end;

function Half(x: real): real;
begin
  Half := x / 2
end;

procedure TwoArgs(a, b: integer);
begin
end;

procedure ByRef(var a: integer);
begin
end;

{ Each of these differs from what it is passed to in exactly *one* of the
  things congruity compares, so the check for that one thing is the only
  thing that can reject it. Three of them were added after a mutation of
  each survived a green suite: the earlier cases all differed in the
  parameter count as well, which is tested first. }
function CharOf(x: integer): char;      { only the result type differs }
begin
  CharOf := chr(x)
end;

procedure TakesChar(x: char);           { only a parameter's type differs }
begin
end;

procedure DeepDiff(procedure p(x: char));  { only the *nested* list differs }
begin
end;

{ 6.6.2 reaches a functional parameter's result type as well as a function's }
procedure BadResult(function f(x: integer): vector);
begin
end;

procedure TakesProc(procedure p(x: integer));
begin
  p(1);
  { a procedural parameter is not a value, and is not a function }
  n := p;
  n := p(1)
end;

procedure TakesFunc(function f(x: integer): integer);
begin
  n := f(1);
  { a functional parameter is not a procedure statement }
  f(1);
  { and one that takes arguments is not a value }
  n := f
end;

procedure Nested(procedure outer(procedure inner(x: integer); y: integer));
begin
end;

procedure NestedOne(procedure outer(procedure inner(x: integer)));
begin
end;

{ 6.6.3.6: "Two formal-parameter-lists shall be congruous if they contain the
  same number of formal-parameter-sections and if the formal-parameter-sections
  in corresponding positions match", and b) adds "containing the same number of
  parameters". `(var a, b: integer)` is one section of two; `(var a: integer;
  var b: integer)` is two sections of one. }
procedure OneSection(procedure p(var a, b: integer));
begin
end;

procedure TwoSections(var a: integer; var b: integer);
begin
end;

begin
  { an actual parameter that is not a name at all }
  TakesProc(n + 1);
  { a name that is not a procedure or a function }
  TakesProc(v);
  { a name that is nothing }
  TakesProc(nowhere);
  { 6.6.3.7: a required procedure or function may not be passed }
  TakesProc(writeln);
  TakesFunc(abs);
  { 6.6.3.6: the parameter lists must be congruous }
  TakesProc(TwoArgs);
  TakesProc(ByRef);
  TakesProc(Twice);
  TakesFunc(Show);
  TakesFunc(Half);
  { the three one-difference cases }
  TakesFunc(CharOf);
  TakesProc(TakesChar);
  { and congruity is recursive: TakesProc's list is not Nested's, and
    DeepDiff's differs from NestedOne's only one level down }
  Nested(TakesProc);
  NestedOne(DeepDiff);
  { 6.6.3.6 compares formal-parameter-*sections*: one section of two names is
    not two sections of one name each, however alike the parameters are }
  OneSection(TwoSections)
end.
