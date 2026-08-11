{ ISO/IEC 10206:1991 §6.4.4 makes a domain-type a type-name *or* a
  schema-name, and §6.7.5.3 gives `new(p, d1, ..., ds)` the tuple the created
  variable's type is produced with. Such a variable has no activation record to
  keep a descriptor in, so its tuple is a header immediately in front of it and
  the pointer denotes the variable rather than the block — which is what leaves
  every other thing a pointer does unchanged. }
program SchemaPointer(output);
type vector(n: integer) = array [1..n] of integer;
     vp = ^vector;
     grid(rows, cols: integer) = array [1..rows, 1..cols] of integer;
     gp = ^grid;

     { §6.4.7 permits a schema to name itself in a pointer domain and nowhere
       else, which is what makes a recursive structure possible. The pointer is
       written first and the schema second, so the domain is the forward
       reference ADR-0019 calls the language's only one. }
     sp = ^seq;
     seq(n: integer) = array [1..n] of sp;

     { A component whose alignment is the widest this target has. The header
       must be a multiple of it or the variable it sits in front of is
       misaligned — a set is 256 bits and the target aligns one to 16, which is
       the fact ADR-0028 learned by segfaulting. A header rounded to 8 instead
       passes every other case here and faults on this one. }
     bits(n: integer) = array [1..n] of set of char;
     bitp = ^bits;

var p, q: vp;
    g: gp;
    head: sp;
    bs: bitp;
    i, j, k: integer;

procedure show(var v: vector);
var i: integer;
begin
  write('(', v.n:1, ')');
  for i := 1 to v.n do write(v[i]:4);
  writeln
end;

{ A heap variable is passed to a schematic formal exactly as any other variable
  of a produced type is: the tuple travels beside the address, read out of the
  header rather than out of a caller's descriptor. }
procedure fill(var v: vector);
var i: integer;
begin
  for i := 1 to v.n do v[i] := i * i
end;

begin
  { A discriminant that is a constant, and one that is not — §6.7.5.3 requires
    neither, because the tuple is chosen when new runs. }
  new(p, 3);
  fill(p^);
  show(p^);

  k := 5;
  new(q, k);
  fill(q^);
  show(q^);

  { The variable is reached through the pointer, so its bounds are checked
    against a tuple no part of the program wrote down. }
  writeln('n is ', q^.n:1, ', last is ', q^[q^.n]:1);

  { Assignment between two schematic types, where one of them is on the heap
    (ADR-0042). The tuples agree, so the copy happens. }
  new(p, 5);
  p^ := q^;
  show(p^);

  { More than one discriminant, and an inner dimension whose bound is the
    second of them — one header serves every level. }
  new(g, 2, 3);
  for i := 1 to g^.rows do
    for j := 1 to g^.cols do
      g^[i, j] := i * 10 + j;
  for i := 1 to g^.rows do begin
    for j := 1 to g^.cols do write(g^[i, j]:4);
    writeln
  end;

  { A structure of heap variables, each with its own tuple, reached through a
    component of another. }
  new(head, 2);
  new(head^[1], 3);
  head^[2] := nil;
  for i := 1 to head^[1]^.n do head^[1]^[i] := nil;
  writeln('head has ', head^.n:1, ', its first has ', head^[1]^.n:1);

  { A set component, whose alignment the header has to preserve. }
  new(bs, 2);
  bs^[1] := ['a'..'e'];
  bs^[2] := [];
  if 'c' in bs^[1] then writeln('c is in the first of ', bs^.n:1)
  else writeln('lost');
  if bs^[2] = [] then writeln('the second is empty');
  dispose(bs);

  dispose(g);
  dispose(q);
  dispose(p);
  writeln('done')
end.
