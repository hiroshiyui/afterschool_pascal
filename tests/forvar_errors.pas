{ Where a for statement's control variable may be declared.

  §6.8.3.9 does not say "a variable". It says "The control-variable shall be an
  entire-variable whose identifier is declared in the variable-declaration-part
  of the block closest-containing the for-statement" — ISO/IEC 10206:1991
  §6.9.3.9.2 word for word, but for "a variable-declaration-part", that
  standard letting the parts repeat (§6.2.1). Three things follow, and only the
  first was checked:

  - it must be a variable, so a parameter and a constant are refused;
  - it must be declared in *this* block, so a variable of an enclosing block
    is refused even though the body can perfectly well assign to it;
  - it must be an entire-variable, so a field is refused — which the parser
    already does for `r.i`, there being no `.` after a control-variable, and
    Sema does for the field a `with` puts a bare name in front of.

  The middle one had no program. `for i := 1 to 3` inside a procedure, over
  the *program's* `i`, compiled and ran and printed the right numbers; nothing
  in the corpus wrote one, so nothing noticed that §6.8.3.9 forbids it. It is
  the shape a reader is least likely to suspect, because it is what most
  languages allow and what the generated code would happily do.

  The message names the rule rather than the symptom. "must be a variable" was
  what a parameter used to get, and a value parameter *is* a variable — the
  complaint is about where it was declared, not about what it is. }
program ForVarErrors(output);

const
  limit = 10;

type
  point = record x, y: integer end;

var
  outer: integer;
  p: point;
  r: real;

{ The control variable of a for statement in *this* block must be declared in
  this block. `outer` is the program's. }
procedure usesEnclosing;
begin
  for outer := 1 to 3 do
    writeln(outer:1)
end;

{ A value parameter is a variable and is not declared in a
  variable-declaration-part. }
procedure usesParameter(n: integer);
begin
  for n := 1 to 3 do
    writeln(n:1)
end;

begin
  { A constant is not a variable at all. }
  for limit := 1 to 3 do
    writeln(limit:1);

  { §6.8.3.9's second sentence: the control-variable shall possess an ordinal
    type. }
  for r := 1.0 to 3.0 do
    writeln(r:1:1);

  { An entire-variable, so not a field — here the one a `with` has put a bare
    name in front of. }
  with p do
    for x := 1 to 3 do
      writeln(x:1);

  usesEnclosing;
  usesParameter(0)
end.
