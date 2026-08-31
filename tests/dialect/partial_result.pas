{ 6.7.2 requires a function-block to write its result at least once, and this
  compiler reports a body that never does. What nothing asked until ADR-0278 is
  whether the one assignment stands where *every* path reaches it: an if with
  no else-part, or one arm of two, leaves the result whatever the frame slot
  happened to hold, and the program compiles and runs.

  It is a warning and not an error because 6.7.2 is satisfied -- the block does
  contain an assignment -- and what is wrong is where it stands. Every function
  here is called only down a path that does write, so the program's output says
  nothing about the paths that do not.

  Three shapes answer *yes* and each must:

  - a statement-sequence, as soon as one of its statements does;
  - an if-statement, only with **both** arms -- so no else-part is an outright
    no, and one arm of two is not enough either;
  - a case-statement, with every arm *and* the completer -- unless there is no
    completer at all, 6.9.3.5 stopping the program when no label matches, so a
    path that returns is a path that took an arm.

  6.7.5.7's halt answers yes for that second reason and writes nothing: no path
  through it returns to read a result. AP 6.7.5.9's exit(e) writes and leaves,
  and the walk finds the assignment Sema moved into the husk.

  Four things silence it, and each is a case the walk cannot decide rather than
  one it decides in the program's favour: a goto anywhere in the body,
  6.8.2.2's assignment made by a *nested* procedure, a result-variable-
  specification -- the one spelling a `read` or a var argument can name -- and
  a repeat whose condition is the constant false, which is never left by
  falling out of it. }
program partial_result(output);
{ 6.13's other program-component, and the third guard: Sema checks the whole
  of an imported component, so `Maybe` is exactly the shape this file is about
  and must be reported about nowhere. }
import partial_helper;
type colour = (red, green, blue);
var g: integer;

{ ---- the shapes that are reported ------------------------------------- }

{ one arm of two, and there is no other }
function half(n: integer): integer;
begin
  if n > 0 then half := n div 2
end;

{ a completer that writes nothing }
function tag_(c: colour): char;
begin
  case c of
    red: tag_ := 'r';
    otherwise
      g := g + 1
  end
end;

{ one arm of three that does not write }
function initial(c: colour): char;
begin
  case c of
    red:   initial := 'r';
    green: g := g + 1;
    blue:  initial := 'b'
  end
end;

{ a while may run no times at all }
function firstOf(n: integer): integer;
var i: integer;
begin
  i := 0;
  while i < n do begin
    firstOf := i;
    i := i + 1
  end
end;

{ and so may a for }
function lastOf(n: integer): integer;
var i: integer;
begin
  for i := 1 to n do lastOf := i
end;

{ a repeat runs once and is still left by a break }
function untilBig(n: integer): integer;
begin
  repeat
    if n > 2 then break;
    untilBig := n;
    n := n + 1
  until n > 10
end;

{ exit(e) writes and leaves -- but only down the arm it is written in }
function early(n: integer): integer;
begin
  if n = 0 then exit(9)
end;

{ `otherwise` followed by nothing: a legal way to say "and otherwise do
  nothing", and so a completer that writes no result }
function bare(c: colour): char;
begin
  case c of
    red: bare := 'r';
    otherwise
  end
end;

{ ---- the shapes that are not ------------------------------------------- }

{ both arms }
function sign_(n: integer): integer;
begin
  if n < 0 then sign_ := -1 else sign_ := 1
end;

{ one arm of two that writes and one that does not: the shape that says the
  two arms are required *together* and not either of them }
function oneOf(n: integer): integer;
begin
  if n > 0 then oneOf := n else g := g + 1
end;

{ exit(e) as the other arm, so the walk has to follow the husk Sema built to
  answer yes here }
function viaExit(n: integer): integer;
begin
  if n > 0 then viaExit := n else exit(0)
end;

{ every arm, and no completer: an unmatched selector stops the program }
function letter(c: colour): char;
begin
  case c of
    red:   letter := 'r';
    green: letter := 'g';
    blue:  letter := 'b'
  end
end;

{ every arm and a completer that writes }
function firstChar(c: colour): char;
begin
  case c of
    red: firstChar := 'r';
    otherwise
      firstChar := '?'
  end
end;

{ halt: the path that does not write does not return either. Written with
  both arms, because an if with no else-part is already an outright no and the
  walk would never look inside it. }
function orStop(n: integer): integer;
begin
  if n = 0 then halt else orStop := n
end;

{ a with-statement is looked through, as a labelled statement is }
function fieldOf(n: integer): integer;
label 1;
type pair = record a, b: integer end;
var p: pair;
begin
  p.a := n;
  p.b := n + 1;
  with p do
1:  fieldOf := a + b
end;

{ left only by an exit, so falling out of it is not a path }
function scan(n: integer): integer;
begin
  repeat
    if n > 3 then exit(n);
    n := n + 1
  until false
end;

{ A goto makes the statement tree a graph and the walk says so: no path
  through *this* body writes the result as far as the walk can see, and the
  jump is why it cannot see one. It is called only where n is positive. }
function jumps(n: integer): integer;
label 1;
begin
  if n > 0 then begin
    jumps := n;
    goto 1
  end;
  if n < 0 then jumps := -n;
1:
  g := g + 0
end;

{ 6.8.2.2's containment: a nested procedure may write the result }
function nested(n: integer): integer;
  procedure writeIt;
  begin
    nested := n * 2
  end;
begin
  if n > 0 then writeIt
end;

{ 6.7.2's result-variable-specification, the one spelling 6.9.4's other
  threats can name }
function named(n: integer) = r: integer;
begin
  if n > 0 then r := n
end;

begin
  g := 0;
  writeln(half(4):1, ' ', tag_(red), ' ', initial(red), ' ',
          firstOf(2):1, ' ', lastOf(3):1, ' ', untilBig(1):1, ' ',
          early(0):1, ' ', bare(red));
  writeln(sign_(-2):1, ' ', oneOf(4):1, ' ', viaExit(5):1, ' ',
          letter(green), ' ', firstChar(blue), ' ',
          orStop(5):1, ' ', fieldOf(1):1, ' ', scan(1):1, ' ',
          jumps(2):1, ' ', nested(2):1, ' ', named(3):1);
  writeln('g = ', g:1, ', imported = ', Maybe(6):1)
end.
