{ ISO/IEC 10206:1991 §6.4.9's type-inquiry:

    type-inquiry        = 'type' 'of' type-inquiry-object .
    type-inquiry-object = variable-name | parameter-identifier .

  "The type denoted by a type-inquiry shall be the type possessed by the
  variable-identifier or parameter-identifier contained by the type-inquiry."

  It is the only type-denoter that names a *variable*, and the whole feature is
  that one sentence: what comes back is the type that variable already has, not
  a second type alike it. Under §6.4.5's name equivalence that distinction is
  the entire point — `b: type of a` can be assigned from `a`, where a second
  `record x, y: integer end` written out could not.

  Both of its words are already reserved in ISO 7185, so — like `and then`
  (ADR-0038) — this feature reserves nothing. }
program TypeInquiry(output);
type point = record x, y: integer end;
     colour = (red, green, blue);

var a: point;
    { the same type as `a`, which is what makes the assignment below legal }
    b: type of a;
    n: integer;
    m: type of n;
    c: colour;
    { §6.4.2.1: "A type-inquiry in an ordinal-type shall denote an
      ordinal-type." Here it does, so it may index an array. }
    tally: array [type of c] of integer;
    grid: array [1..3] of type of n;
    { a type-inquiry may name a variable whose own type came from one }
    d: type of b;

{ §6.4.9 allows the object to be a parameter of the *closest-containing*
  formal-parameter-list, which is what makes this the useful form: one
  parameter's type is written once and the other follows it. }
procedure copy(protected var src: point; var dst: type of src);
begin
  dst := src
end;

{ ...and it reaches an ordinary variable of an enclosing scope just as well.
  Not the result type, though: §6.7.2 spells that `result-type = type-name`
  and stops there, so `type of n` is a parameter's form and not a result's. }
function doubled(k: type of n): integer;
begin
  doubled := k * 2
end;

procedure show(protected var p: type of a);
begin
  writeln(p.x:1, ' ', p.y:1)
end;

begin
  a.x := 1; a.y := 2;
  copy(a, b);
  show(b);
  d := b;                     { one type, so a whole-variable assignment }
  d.x := 9;
  show(d);
  show(a);

  n := 20; m := doubled(n);
  writeln(m:1);

  for c := red to blue do tally[c] := ord(c) * 10;
  writeln(tally[red]:1, tally[green]:1, tally[blue]:1);

  grid[1] := 5; grid[3] := grid[1] + 1;
  writeln(grid[1]:1, grid[3]:1)
end.
