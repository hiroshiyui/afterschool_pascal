{ ISO/IEC 10206:1991 6.9.4 b): "S contains V in an actual-parameter that is an
  actual variable parameter corresponding to a formal variable parameter that
  is not protected". A variable-conformant-array-parameter is a formal variable
  parameter -- 6.7.3.7.3 calls it one in those words, "Each actual-parameter
  corresponding to a formal variable parameter shall be a variable-access" --
  so an actual passed to one is threatened exactly as an actual passed to an
  ordinary var parameter is.

  6.7.2 reads that list to decide whether a function-block "shall contain at
  least one statement threatening" its result variable. With b) unapplied here,
  a function that fills its result by handing it to a conformant array
  procedure was refused -- "never writes to its result variable" -- which is
  the shape of the same defect ADR-0169 fixed for `new`, one letter of the
  same list over.

  A *value* conformant array is deliberately not a threat: b) says variable
  parameter, and 6.7.3.7.2 attributes the expression's value to a variable of
  the activation, so nothing of the actual is written. The last function here
  is what says so -- it needs a second statement to be legal at all.

  Extended Pascal only: ISO 7185 has no result-variable-specification, and
  6.6.2 there asks for syntactic containment of an assignment instead. }
program conformant_threatens_result(output);

type
  triple = array [1..3] of integer;
  pair = record lo, hi: triple end;

procedure fill(var a: array [lo..hi: integer] of integer; seed: integer);
var i: integer;
begin
  for i := lo to hi do a[i] := seed + i
end;

{ The whole point: `fill(res)` is the only statement that writes res. }
function ramp(seed: integer) = res: triple;
begin
  fill(res, seed)
end;

{ 6.9.4 h): a threat to a component is a threat to the variable containing it,
  so neither statement here writes res and both threaten it. }
function two = res: pair;
begin
  fill(res.lo, 10);
  fill(res.hi, 20)
end;

{ 6.7.3.7.2's value form copies, so it threatens nothing -- the assignment is
  what makes this function legal, and removing `fill` would leave it so. }
procedure total(a: array [lo..hi: integer] of integer; var sum: integer);
var i: integer;
begin
  sum := 0;
  for i := lo to hi do sum := sum + a[i]
end;

function copied = res: triple;
var t: integer;
begin
  res[1] := 1; res[2] := 2; res[3] := 3;
  total(res, t);
  res[1] := t
end;

var
  r: triple;
  p: pair;
  c: triple;

begin
  r := ramp(100);
  writeln(r[1]:1, ' ', r[2]:1, ' ', r[3]:1);
  p := two;
  writeln(p.lo[3]:1, ' ', p.hi[3]:1);
  c := copied;
  writeln(c[1]:1)
end.
