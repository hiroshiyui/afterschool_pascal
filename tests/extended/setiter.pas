{ ISO/IEC 10206:1991 §6.9.3.9.3's set-member-iteration. The for-statement's
  iteration-clause has two forms and this is the second: `for v in s do` runs
  the body once per member of s. }
program setiter(output);
type
  hue  = (red, green, blue, violet);
  hues = set of hue;
  digits = set of 1..9;
var
  h: hue;
  c: char;
  i, n: integer;
  s: digits;
  cs: set of char;
  hs: hues;
  narrow: 1..5;
  seen: array [hue] of integer;

procedure show(x: hue);
begin write(ord(x):2) end;

begin
  { §6.9.3.9.3 leaves the order implementation-dependent; this compiler visits
    members in ascending ordinal order, which is what walking the bits gives. }
  hs := [red, blue];
  write('h'); for h in hs do show(h); writeln;

  { "Each value, if any, that is a member" — an empty set runs the body no
    times, and the empty-set constructor has no base type to ask, so the
    control variable's own range serves. }
  for h in [] do write('never');
  writeln('empty ok');

  s := [1, 3, 5..7];
  n := 0;
  write('s');
  for i in s do begin write(i:2); n := n + i end;
  writeln(' sum ', n:1);

  cs := ['a', 'e', 'z'];
  write('c ');
  for c in cs do write(c);
  writeln;

  { "The set-expression shall be evaluated prior to the first execution, if
    any, of the statement" — so assigning to the variable inside the body
    cannot change what is iterated. A set is a value, which is why there is
    nothing else to say about it. }
  s := [1, 2];
  write('once');
  for i in s do begin write(i:2); s := [8, 9] end;
  writeln;

  { The control variable may be narrower than the base type, as long as every
    member fits: §6.9.3.9.3 makes the *members* assignment-compatible, not the
    set. }
  s := [2, 4];
  write('narrow');
  for narrow in s do write(narrow:2);
  writeln;

  { The body is an ordinary statement, so it may contain another one — and the
    control variables must differ, because §6.9.4 g) makes a for-statement
    threaten its own. }
  for h in [red, violet] do
    for i in [1, 2] do
      write(' ', ord(h):1, i:1);
  writeln;

  { A set-expression, not just a set variable. }
  for h in hs + [green] do show(h);
  writeln;

  for h in [red..violet] do seen[h] := 0;
  for h in [green, violet] do seen[h] := 1;
  write('seen');
  for h in [red..violet] do write(seen[h]:2);
  writeln
end.
