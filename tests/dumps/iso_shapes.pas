{ Every tree shape the ISO 7185 dump walkers can be asked to write.

  This program exists for `--dump-all`, not for what it computes. Until it was
  written nothing in the corpus passed any --dump flag at all, so the token,
  AST and Sema walkers -- thirty-one procedures -- were entered by no case,
  while four documented flags claimed to work. tests/checks/coverage.py is what
  found that; this is half the answer to it.

  So the value here is *breadth*: one of each declaration part, each type
  denoter, each statement form and each operator class, so that a walker with
  no arm for something is a crash rather than a silent gap. It is deliberately
  not a semantics test -- tests/ has those, one construct at a time. }
program shapes(output);
label 1;

const
  n = 3;
  greeting = 'hi';

type
  colour = (red, green, blue);
  small  = 1 .. 9;
  vec    = array [1 .. n] of integer;
  str3   = packed array [1 .. 3] of char;
  hue    = set of colour;
  { §6.4.3.3: the labels of a variant part are exactly its tag-type's values,
    so these three arms cover 1 .. 9 with nothing left over (ADR-0096). Both
    label forms ISO 7185 has are here -- one constant and a list -- because
    DumpCaseLabels writes them differently. A *range* is Extended Pascal's
    (ADR-0035) and is exercised by ext_shapes.pas. }
  shape  = record
             tint: colour;
             case kind: small of
               1:                  (side: integer);
               2, 3:               (w, h: integer);
               4, 5, 6, 7, 8, 9:   (r: real)
           end;
  link   = ^cell;
  cell   = record datum: integer; next: link end;

var
  i, j: integer;
  c: colour;
  v: vec;
  s: str3;
  h: hue;
  sh: shape;
  p: link;
  f: text;
  x: real;

function add(a, b: integer): integer;
  { A nested procedure, so the Sema dump has more than one frame to write. }
  procedure noop;
  begin
  end;
begin
  noop;
  add := a + b
end;

{ A var parameter and a subrange parameter: the two passing modes the frame
  layout distinguishes. The control variable is local because §6.8.3.9 requires
  it to be declared in the block the for-statement is in (ADR-0077). }
procedure walk(var q: vec; k: small);
var m: integer;
begin
  with sh do begin
    tint := red;
    kind := 1;
    side := k
  end;
  for m := 1 to n do q[m] := add(q[m], k)
end;

begin
  i := 1;
  j := -2;
  x := 1.5;
  c := blue;
  h := [red, blue];
  s := 'abc';
  v[1] := 0;
  walk(v, 3);
  if (i < j) and not (c = red) then goto 1;
  case c of
    red:   writeln('r');
    green: writeln('g');
    blue:  writeln('b')
  end;
  while i < n do i := i + 1;
  repeat j := j + 1 until j >= 0;
  new(p);
  p^.datum := i;
  dispose(p);
  { §6.4.4's nil, which is an unsigned-constant and so a factor of its own. }
  p := nil;
1:
  writeln(add(i, j) : 4, ' ', x : 6 : 2, ' ', greeting, ' ', sh.side)
end.
