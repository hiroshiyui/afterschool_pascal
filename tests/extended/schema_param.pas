{ ISO/IEC 10206:1991 §6.7.3.2 and §6.7.3.3: a parameter-form may be a bare
  schema-name, and the formal then possesses the type the *actual* was produced
  from. One body serves every tuple, so the bounds arrive with the argument --
  in a descriptor beside its address, which is what `v.n` reads. }
program SchemaParam(output);
type
  vector(n: integer) = array [1..n] of real;
  grid(w, h: integer) = array [1..w, 1..h] of integer;
  { both bounds may be discriminants, so an array can start anywhere }
  window(lo, hi: integer) = array [lo..hi] of integer;
  text4 = packed array [1..4] of char;
  { NOTE 1 of §6.4.7: a discriminant the body never mentions still makes the
    types distinct, and a schematic formal takes either of them }
  tagged(k: integer) = array [1..3] of char;
var
  small: vector(3);
  large: vector(5);
  board: grid(2, 3);
  win: window(2, 4);
  one: tagged(1);
  two: tagged(2);
  i, j: integer;

{ a var parameter binds to the actual: the bounds are read out of the
  descriptor and the writes are seen by the caller }
procedure fill(var v: vector);
var i: integer;
begin
  for i := 1 to v.n do
    v[i] := i / 2
end;

{ a value parameter is a copy, and its size is not known until the block is
  entered -- so the storage is claimed on entry and the caller sees nothing }
function sum(v: vector): real;
var i: integer; s: real;
begin
  s := 0.0;
  for i := 1 to v.n do
  begin
    s := s + v[i];
    v[i] := 0.0
  end;
  sum := s
end;

{ two dimensions, both of them dynamic: the outer array's component is itself
  an array whose extent arrives with the actual }
procedure show(g: grid);
var i, j: integer;
begin
  write('grid ', g.w:1, 'x', g.h:1, ':');
  for i := 1 to g.w do
    for j := 1 to g.h do
      write(g[i, j]:3);
  writeln
end;

procedure edges(var w: window);
begin
  writeln('window ', w.lo:1, '..', w.hi:1, ' holds ', w[w.lo]:1, ' first and ',
          w[w.hi]:1, ' last')
end;

{ §6.7.3.3's rule is about one formal-parameter-section, not about the schema:
  two sections take two tuples, and this is what says the two are told apart }
procedure both(var a: vector; var b: vector);
begin
  writeln('two sections: ', a.n:1, ' and ', b.n:1)
end;

{ passing one on: the formal's own descriptor is what travels, so a schematic
  array reaches through any number of blocks without ever being copied }
procedure inner(var v: vector);
begin
  v[v.n] := 99.0
end;

procedure outer(var v: vector);
begin
  inner(v)
end;

{ §6.4.7's NOTE 1 again: `tagged(1)` and `tagged(2)` are different types and
  both are this parameter's }
procedure label3(t: tagged);
begin
  writeln('tagged(', t.k:1, ') = ', t[1], t[2], t[3])
end;

{ what makes the descriptor per-invocation rather than per-procedure: `walk`
  is recursive, and the nested procedure inside it must see the tuple of the
  invocation that called it -- not the outermost one, and not the innermost }
procedure walk(var v: vector; depth: integer);
  procedure report;
  begin
    writeln('  depth ', depth:1, ' sees ', v.n:1, ' elements')
  end;
begin
  report;
  if depth < 2 then
    if v.n = 3 then walk(large, depth + 1) else walk(small, depth + 1);
  report
end;

{ a procedural parameter's own formal may be schematic too, and §6.6.3.6's
  congruity is then decided on the schema -- the tuple is the actual's
  business at that call as it is at any other }
procedure apply(procedure p(var v: vector); var v: vector);
begin
  p(v)
end;

procedure zero(var v: vector);
var i: integer;
begin
  for i := 1 to v.n do v[i] := 0.0
end;

begin
  fill(small);
  fill(large);
  writeln('sum of 3 is ', sum(small):3:1, ', of 5 is ', sum(large):4:1);
  writeln('the copy was a copy: ', small[1]:3:1);

  for i := 1 to 2 do
    for j := 1 to 3 do
      board[i, j] := i * 10 + j;
  show(board);

  for i := 2 to 4 do win[i] := i * i;
  edges(win);

  both(small, large);

  outer(small);
  writeln('through two blocks: ', small[3]:4:1);

  one[1] := 'o'; one[2] := 'n'; one[3] := 'e';
  two[1] := 't'; two[2] := 'w'; two[3] := 'o';
  label3(one);
  label3(two);

  walk(small, 0);

  apply(zero, large);
  writeln('after apply: ', large[5]:3:1)
end.
