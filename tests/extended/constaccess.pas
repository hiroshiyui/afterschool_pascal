{ ISO/IEC 10206:1991 §6.8.8's constant-accesses, and the structured constants
  there would be nothing to access without.

  §6.8.8.1's own NOTE is the whole point of the clause:

      Neither a constant-access nor a constant-access-component is necessarily
      a constant. ... the constant-access, c[i], denotes a different value for
      each iteration of the loop.

  So a constant-access is a *run-time read* of storage whose contents were
  fixed at compile time — and where the index happens to be constant too, it
  is a constant, because §6.3.2's own examples use one as `column1 =
  BlankCard[1]`. Both are here.

  The clause adds no run-time check of its own: D.88 to D.91 are the array,
  string and substring bounds this compiler already tests, which is why
  `verify/` gained nothing (ADR-0069). }
program constaccess(output);

{ §6.2.1 makes the block a repetition of the declaration parts in any order,
  and a constant naming a type is why that had to start being honoured: the
  type part below has to be processed before the constant part after it. }
type
  vec     = array [1..4] of integer;
  colour  = (red, green, blue);
  point   = record x, y: integer end;
  points  = array [1..3] of point;
  digits  = set of 0..9;
  shape   = record
              case round: boolean of
                true:  (r: integer);
                false: (w, h: integer)
            end;

const
  { §6.8.7.2's array-value, with a completer for what the elements leave. }
  squares = vec[1: 1; 2: 4; 3: 9; 4: 16];
  sparse  = vec[2: 20 otherwise 7];
  { §6.8.7.3's record-value, and one with a variant-part-value. }
  origin  = point[x: 0; y: 0];
  circle  = shape[case round: true of [r: 5]];
  { §6.8.7.4's set-value, which needs no storage at all: a set is a value. }
  odds    = digits[1, 3, 5, 7, 9];
  { A constant may name another constant, and then the two denote one value —
    here, literally: they share one global. }
  same    = squares;
  { An enumeration constant is only in scope after its type part, which is the
    order this block is written in. }
  first   = red;
  { A structured constant of a structured component type. }
  corners = points[1: point[x: 1; y: 2];
                   2: point[x: 3; y: 4];
                   3: point[x: 5; y: 6]];
  hex     = '0123456789ABCDEF';

{ §6.8.8.2, §6.8.8.3 and §6.8.8.4 in a *constant-definition*, where every
  index is itself constant — §6.8.2 guarantees that, since a variable index
  would be a variable-access and a constant-expression may not contain one. }
const
  third    = squares[3];       { an indexed-constant  — §6.8.8.2 }
  filler   = sparse[4];        { ...answered by the completer     }
  radius   = circle.r;         { a field-designated-constant — §6.8.8.3 }
  ycorner  = corners[2].y;     { and one selected through a subscript }
  column1  = hex[1];           { a string-constant indexed — §6.8.8.2 }
  low      = hex[1..10];       { a substring-constant — §6.8.8.4 }
  high     = hex[11..16];
  { §6.1.7's doubled apostrophe is *one* character of the value, so a
    substring-constant counts characters and not source text. The Pascal
    compiler narrows the run of string pool the literal already interned
    rather than interning new characters, which is only sound because what
    is in the pool is the value — this is the program that says so. And a
    substring of a substring, because the narrowed run must itself be one. }
  quoted   = 'it''s a ''test''';
  itis     = quoted[1..4];
  inner    = itis[2..4];
  apost    = quoted[3];

{ A folded constant-access is a constant like any other, so it may bound an
  array and label a case — which is the whole reason folding is worth doing. }
type
  row = array [1..third] of integer;

var
  i: integer;
  r: row;
  p: point;

{ §6.3.1 fixes a constant's value for the whole program, so a constant defined
  in a recursive procedure is the same value at every depth — one global,
  filled once by the prologue of the block that defined it. }
procedure deep(n: integer);
const inner = point[x: 8; y: 9];
begin
  if n > 0 then
    deep(n - 1);
  write(' ', inner.x:1, inner.y:1)
end;

begin
  { §6.8.8.1's NOTE: the index is a variable, so this is a run-time read. }
  write('squares');
  for i := 1 to 4 do
    write(' ', squares[i]:1);
  writeln;

  write('sparse ');
  for i := 1 to 4 do
    write(' ', sparse[i]:1);
  writeln;

  { The two names share one value and therefore one storage. }
  write('same   ');
  for i := 1 to 4 do
    write(' ', same[i]:1);
  writeln;

  writeln('folded  ', third:1, ' ', filler:1, ' ', radius:1, ' ', ycorner:1);
  writeln('strings ', column1, ' ', low, ' ', high);
  writeln('quoted  [', quoted, '] [', itis, '] [', inner, '] [', apost, ']');
  writeln('first   ', ord(first):1);

  { A constant-access is a value, so it may be assigned *from*, compared, and
    passed to a value parameter — none of which makes it a variable. }
  p := corners[3];
  writeln('copied  ', p.x:1, p.y:1);
  if origin.x = 0 then
    writeln('compared');

  { A set constant is a value with no storage: the constructor is emitted
    where the name is written. }
  write('odds    ');
  for i := 0 to 9 do
    if i in odds then
      write(' ', i:1);
  writeln;

  { §6.9.3.10's with-element may be a constant-access. The names it introduces
    are constant-field-identifiers, which denote values — assigning to one is
    refused in constaccess_errors.pas. }
  with corners[1] do
    writeln('with    ', x:1, y:1);

  { The folded bound really is a bound. }
  for i := 1 to third do
    r[i] := i * i;
  writeln('row     ', r[third]:1);

  case third of
    9: writeln('labelled')
  end;

  write('deep    ');
  deep(2);
  writeln
end.
