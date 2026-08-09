program Procedures(output);

{ Value and var parameters, recursion, functions, forward declarations, and
  the parameterless call that is written as a bare name. }

var
  x, y, n: integer;

function Fact(n: integer): integer;
begin
  if n <= 1 then
    Fact := 1
  else
    Fact := n * Fact(n - 1)   { the name on the right is the recursive call }
end;

procedure Swap(var a, b: integer);
var
  t: integer;
begin
  t := a;
  a := b;
  b := t
end;

procedure Bump(var v: integer; by: integer);
begin
  v := v + by      { writes through the reference }
end;

{ Mutual recursion needs one of the pair declared forward. }
function IsOdd(k: integer): boolean; forward;

function IsEven(k: integer): boolean;
begin
  if k = 0 then IsEven := true else IsEven := IsOdd(k - 1)
end;

function IsOdd;        { the completion repeats the name only }
begin
  if k = 0 then IsOdd := false else IsOdd := IsEven(k - 1)
end;

function Answer: integer;
begin
  Answer := 42
end;

procedure Banner;
begin
  writeln('--- procedures ---')
end;

begin
  Banner;
  writeln('5! = ', Fact(5));

  x := 3;
  y := 8;
  Swap(x, y);
  writeln('swapped: ', x, ' ', y);

  Bump(x, 10);
  writeln('bumped: ', x);

  for n := 0 to 3 do
    writeln(n, ' even=', IsEven(n), ' odd=', IsOdd(n));

  writeln('answer = ', Answer)
end.
