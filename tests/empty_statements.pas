program EmptyStatements(output);
{ ISO 7185 6.8.1 makes an empty statement a statement, so it is legal wherever
  a statement is. Most of these already worked; `if c then <empty> else s` did
  not, and the omission was found the hard way -- by having to write around it
  while porting Sema, where the C++ has a `continue` (ADR-0024).

  The rule is that every token which can *follow* a statement also starts one:
  `;` and `end` between statements, `else` after a then-branch, `until` after a
  repeat body. }

type
  point = record x, y: integer end;

var
  i, n: integer;
  p: point;

begin
  { the then-branch, which is the one that used to be rejected }
  if false then else writeln('empty then: taken else');
  if true then else writeln('NOT REACHED');
  { and nested, so the inner if is what the else belongs to }
  if true then if false then else writeln('empty then: nested');

  { the else-branch }
  if true then writeln('empty else: taken then') else;

  { before `until`, reached through a statement that ends where the repeat
    body does -- this needs `until` to start an empty statement too }
  n := 0;
  repeat
    n := n + 1;
    if n = 1 then
  until n = 2;
  writeln('empty then before until: ', n:1);

  n := 0;
  repeat
    n := n + 1;
    while false do
  until n = 3;
  writeln('empty while body before until: ', n:1);

  { the bodies of the structured statements. The control variable is undefined
    after a for loop (6.8.3.9), so nothing here reads it afterwards. }
  while false do;
  for i := 1 to 3 do;
  writeln('empty loop bodies: ok');

  p.x := 4;
  with p do;
  writeln('empty with body: ', p.x:1);

  { between statements, and before `end` }
  n := 0;;
  n := n + 1;
  case n of
    1: ;
    2: writeln('NOT REACHED')
  end;
  writeln('empty case arm: ', n:1);
  begin end;
end.
