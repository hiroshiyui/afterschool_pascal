{ A result-variable-specification reaches a `forward`-declared body.

  §6.7.2 puts the identifier's defining-point as a variable-identifier in "the
  block of the function-block, if any, associated with the identifier of the
  function-heading". Two things in that sentence do the work: **if any**, which
  is there because a `forward` declaration has no block of its own, and
  **associated with the identifier**, which is what reaches the block written
  later.

  The clause settles it by parallel construction rather than by saying so. One
  paragraph on it says of the other half of a heading:

    "The occurrence of a formal-parameter-list in a function-heading of a
     function-declaration shall define the formal-parameters of the
     function-block, if any, associated with the identifier of the
     function-heading to be those of the formal-parameter-list."

  Identical phrase, identical "if any". Parameters have always reached a
  forward body -- `a` and `b` below have never been in doubt -- so the result
  variable reaches it too, and the compiler binding one and not the other was
  an asymmetry with nothing behind it. It bound the parameters from the
  *symbol* and the result variable from the *declaration node*, and a forward
  body's node carries no specification to read.

  §6.11.1 makes every function of a module-heading a forward, so this reached
  every exported function of every module in lib/: each had to accumulate into
  a local and assign the identifier once, and doc/sop.md §7 carried it as a
  reading nobody had taken.

  Both routes to a forward are here: the explicit directive, and a module. }
program ForwardResultVar(output);

type
  Point = record x, y: integer end;
  Line = string(32);

{ the explicit directive: the heading has the specification, the block does not }
function MakePoint(a, b: integer) = r: Point; forward;

{ one that returns a string, so the result variable is accumulated into rather
  than assigned once -- which is the whole reason the specification exists }
function Shout(s: Line) = t: Line; forward;

{ a value the body computes in several steps, to show the result variable is a
  variable and not a write-once slot }
function Total(n: integer) = sum: integer; forward;

{ and one *without* a specification, forward-declared, so the older path stays
  exercised: this body must assign the function identifier }
function Twice(n: integer): integer; forward;

function MakePoint;
begin
  r.x := a;
  r.y := b
end;

function Shout;
var k: integer;
begin
  t := '';
  for k := 1 to length(s) do
    if (s[k] >= 'a') and (s[k] <= 'z') then
      t := t + chr(ord(s[k]) - ord('a') + ord('A'))
    else
      t := t + s[k]
end;

function Total;
var k: integer;
begin
  sum := 0;
  for k := 1 to n do
    sum := sum + k;
  { read it back: it is an ordinary variable, so this is not a recursive call }
  sum := sum * 2
end;

function Twice;
begin
  Twice := n * 2
end;

var p: Point;
begin
  p := MakePoint(3, 4);
  writeln('point ', p.x:1, ' ', p.y:1);
  writeln('shout ', Shout('hello, world'));
  writeln('total ', Total(4):1);
  writeln('twice ', Twice(21):1)
end.
