{ §6.9.3.9.3's two rules of its own, and the three §6.9.3.9.1 already had —
  the general clause sits above the split, so a set-member-iteration inherits
  every restriction on the control-variable. }
program setiter_errors(output);
type rec = record f: integer end;
var
  i: integer;
  c: char;
  r: rec;
  s: set of 1..9;
  p: ^integer;
  b: boolean;
begin
  { the set-expression must be a set }
  for i in 5 do writeln(i);
  for i in 'x' do writeln(i);
  { the control variable must be able to take the members }
  for c in s do writeln(c);
  { and it is still an entire variable of an ordinal type }
  for r in s do writeln(r.f);
  with r do
    for f in s do writeln(f);
  for p in s do writeln(p^);
  b := true;
  writeln(b)
end.
