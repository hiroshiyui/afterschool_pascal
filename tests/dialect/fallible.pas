{ AP 6.4.13: a fallible-type, `T ! E` (ADR-0176). It is the result record
  ADR-0120 tells a module to write, with the field names fixed by the
  language: `ok` says which outcome, `val` is the value and `cause` is the
  reason, and reading the arm the tag does not select stops the program
  (ADR-0118) -- which tests/dialect/trap_fallible.pas is.

  What this case pins is that it is a *type*: it copies, it is a parameter, a
  field and a component, and a function answers one. }
program fallible(output);

type
  Code = (none_, syntax, range_, absent);
  IntResult = integer ! Code;
  TextResult = string(16) ! Code;
  Pair = record a, b: IntResult end;
  Triple = array [1..3] of IntResult;
  { a fallible inside a schema body, so the two walkers that re-resolve a
    body per tuple reach one (6.4.8) }
  Sack(cap: integer) = record slot: array [1..cap] of IntResult end;
  SackPtr = ^Sack;

var
  r, s: IntResult;
  t: TextResult;
  p: Pair;
  row: Triple;
  i: integer;
  bag, other: SackPtr;

procedure show(what: string(20); r: IntResult);
begin
  write(what, ': ok=', r.ok);
  if r.ok then writeln(' val=', r.val:1)
  else writeln(' cause=', ord(r.cause):1)
end;

{ the two assignments, and which one was written decides the outcome }
function Parse(s: string(16)): IntResult;
var n, k: integer; bad: boolean;
begin
  n := 0;
  bad := (length(s) = 0);
  for k := 1 to length(s) do
    if (s[k] >= '0') and (s[k] <= '9') then n := n * 10 + (ord(s[k]) - ord('0'))
    else bad := true;
  if bad then Parse := syntax
  else if n > 1000 then Parse := range_
  else Parse := n
end;

{ a fallible of a string, so that the value side is structured }
function Name(k: integer): TextResult;
begin
  if k = 1 then Name := 'one'
  else Name := absent
end;

begin
  { construction from either side, through a function result }
  show('parse 42', Parse('42'));
  show('parse x', Parse('x'));
  show('parse 99999', Parse('99999'));

  { and directly }
  r := 7;
  show('assigned a value', r);
  r := absent;
  show('assigned a cause', r);

  { the whole thing is a value: it copies }
  r := 5;
  s := r;
  r := syntax;
  show('the copy', s);
  show('the original', r);

  { the field assignments say which arm without the shorthand, and set the
    tag exactly as the shorthand does }
  r.val := 11;
  show('r.val := 11', r);
  r.cause := range_;
  show('r.cause := range', r);

  { a component of a record and of an array }
  p.a := 1;
  p.b := syntax;
  show('p.a', p.a);
  show('p.b', p.b);
  for i := 1 to 3 do
    if i = 2 then row[i] := syntax else row[i] := i * 10;
  for i := 1 to 3 do
    show('row', row[i]);

  { a structured value side }
  t := Name(1);
  write('name 1: ok=', t.ok);
  if t.ok then writeln(' val=[', t.val, ']');
  t := Name(2);
  writeln('name 2: ok=', t.ok, ' cause=', ord(t.cause):1);

  { a schema whose body holds one: the body is resolved once per tuple, so a
    second production is what makes the walkers that forget a resolved body
    run over a fallible denoter (6.4.8) }
  new(other, 1);
  other^.slot[1] := 8;
  show('other', other^.slot[1]);
  dispose(other);
  new(bag, 2);
  bag^.slot[1] := 4;
  bag^.slot[2] := syntax;
  show('bag 1', bag^.slot[1]);
  show('bag 2', bag^.slot[2]);
  dispose(bag);

  { the tag is readable, and it is what a caller branches on }
  r := 3;
  if r.ok then writeln('branching on the tag works')
end.
