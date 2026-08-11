{ §6.4.6: assignment-compatibility for two types produced from one schema.
  a) is "the same type", and §6.4.8 makes one schema with one tuple one type —
  so where both tuples are known the compiler decides it. Where one is not
  known until the block is entered, d) makes a mismatch a dynamic-violation:
  the tuples are compared while the program runs, and once they agree the copy
  is the ordinary whole-variable one with a computed length. }
program SchemaAssign(output);
type vector(n: integer) = array [1..n] of real;
     grid(rows, cols: integer) = array [1..rows, 1..cols] of integer;

var g3: vector(3);
    i: integer;

procedure show(var v: vector);
var i: integer;
begin
  write('(', v.n:1, ')');
  for i := 1 to v.n do write(v[i]:5:1);
  writeln
end;

{ Both sides generic, and neither length is known here: one compiled body
  copies a vector of any length onto another of the same length. }
procedure copy(var dst: vector; var src: vector);
begin
  dst := src
end;

{ A generic on one side and a known tuple on the other. The check is the same
  comparison; only one of its operands is a constant. }
procedure fill(var v: vector);
var three: vector(3);
begin
  three[1] := 7.0; three[2] := 8.0; three[3] := 9.0;
  v := three
end;

{ A discriminant evaluated on entry (§6.2.3.2), assigned to another of the
  same block — two descriptors, one tuple, and a length neither the compiler
  nor the caller knew. }
procedure entry(m: integer);
var s, t: vector(m);
    i: integer;
begin
  for i := 1 to m do s[i] := i / 2;
  t := s;
  show(t)
end;

{ More than one discriminant, and an array whose component is itself sized by
  one of them: every discriminant is compared, not just the one a bound used. }
procedure square(var a: grid; var b: grid);
var i, j: integer;
begin
  a := b;
  for i := 1 to a.rows do begin
    for j := 1 to a.cols do write(a[i, j]:3);
    writeln
  end
end;

var p, q: grid(2, 3);

begin
  for i := 1 to 3 do g3[i] := i;
  show(g3);

  fill(g3);
  show(g3);

  { A whole-variable assignment between two variables of one produced type is
    what it always was: the tuples are both known, so nothing is compared. }
  entry(4);
  entry(1);

  for i := 1 to 3 do g3[i] := i * 10;
  copy(g3, g3);
  show(g3);

  for i := 1 to 3 do begin
    q[1, i] := i;
    q[2, i] := i * i
  end;
  square(p, q)
end.
