{ AP 6.7.5.10 and 6.7.5.11: what `break` and `continue` do in each of the four
  repetitive-statements the dialect has.

  The continue cases are the ones worth reading. 6.7.5.11 enumerates the four
  forms rather than saying "the beginning of the loop", because a for-statement
  tests the control-variable against the final-value *after* its statement --
  so continuing at the head would run the body again with the same value and
  never terminate. Each `continue` below is written so that entering the wrong
  block is an infinite loop or a wrong total rather than the same answer.

  The last two are 6.7.5.10's NOTE 2 and NOTE 3: a sequence left by a break is
  not completed, so what it armed waits for the activation, and a for-statement
  left by one is not completed either, so its control-variable keeps the value
  it had. }
program break_continue(output);
var i, j, n: integer; c: char; s: set of char; t: utf8(32); e: utf8(8);

{ 6.7.5.10 NOTE 2: the deferred writeln is armed inside a sequence the break
  leaves, so it runs where the *activation* ends and not where the loop does.
  The k=1 iteration completes its sequence normally and prints there; the k=2
  one is left by the break and prints after 'P left its loop'. Reversing that
  order -- running the armed statement at the break -- is the mutation this
  case exists to catch. }
procedure P;
var k: integer;
begin
  for k := 1 to 3 do begin
    defer writeln('armed at k=', k:1);
    if k = 2 then break
  end;
  writeln('P left its loop')
end;

begin
  { while: break stops it, continue re-evaluates the condition }
  i := 0;
  while true do begin
    i := i + 1;
    if i = 3 then break
  end;
  writeln('while break i=', i:1);

  n := 0;
  i := 0;
  while i < 10 do begin
    i := i + 1;
    if odd(i) then continue;
    n := n + i
  end;
  writeln('while continue n=', n:1);

  { repeat: 6.7.5.11 b) continues at the condition, which follows the body --
    so `continue` here still tests `i > 100` and the loop terminates. Entering
    the head instead would never reach the test. }
  n := 0;
  i := 0;
  repeat
    i := i + 1;
    if i = 4 then continue;
    if i = 7 then break;
    n := n + i
  until i > 100;
  writeln('repeat n=', n:1, ' i=', i:1);

  { for: 6.7.5.11 c). The continue enters the final-value test, so i still
    reaches 5 and the break there ends it. }
  n := 0;
  for i := 1 to 10 do begin
    if i = 5 then break;
    if i = 2 then continue;
    n := n + i
  end;
  { 6.7.5.10 NOTE 3: not completed, so the control-variable keeps its value }
  writeln('for n=', n:1, ' i=', i:1);

  n := 0;
  for i := 10 downto 1 do begin
    if i < 8 then break;
    n := n + i
  end;
  writeln('downto n=', n:1);

  { 6.7.5.10 NOTE 1: the closest-containing one, so the inner loop only }
  n := 0;
  for i := 1 to 3 do
    for j := 1 to 3 do begin
      if j = 2 then break;
      n := n + 1
    end;
  writeln('nested n=', n:1);

  { for-in over a set: 6.7.5.11 d), the next member }
  s := ['a', 'e', 'i', 'x'];
  n := 0;
  for c in s do begin
    if c = 'x' then break;
    if c = 'e' then continue;
    n := n + 1
  end;
  writeln('set n=', n:1);

  { for-in over a text: 6.7.5.11 d), the next element }
  t := 'abcde';
  n := 0;
  for e in t do begin
    if e = 'd' then break;
    if e = 'b' then continue;
    n := n + 1
  end;
  writeln('text n=', n:1);

  P;
  writeln('after P')
end.
