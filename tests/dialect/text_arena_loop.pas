{ Megabytes of text temporaries through a one-megabyte arena, which is
  tests/extended/str_arena_loop.pas asked of the three producers the text
  model added.

  ADR-0111 releases the arena at the end of any statement that took storage,
  and which statements those are is a *counter* the emitter bumps -- not a
  predicate over the tree. So a producer that forgets to bump it leaks a
  statement at a time, and the failure is silent until the ring wraps: a
  security audit found `a + a = b + b` over two 512K strings calling two
  different values equal and exiting 0. `doc/sop.md` §7 records that nothing
  checks the counter and said a fifth producer would have nothing looking for
  it; three arrived at once with AP 6.4.15.

  One loop per producer, each moving several megabytes through the arena, and
  each written so that the producer under test is the **only** one in its
  statement. That is what makes the loops mutation-sensitive rather than
  merely large: the counter decides whether a *statement* releases, so a bump
  removed from a producer sharing its statement with another is invisible.
  `t := a + b` is exactly that shape -- the join and the store are both in it,
  and dropping the join's bump changes nothing -- which is why the first loop
  compares instead of assigning.

  - 6.4.15.7's join, which allocates because normal form makes the length of
    the result something neither operand knows. Both operands of the
    comparison are texts, so the comparison itself allocates nothing.
  - 6.4.15.5's store from a string, where the bytes are validated and
    normalised on the way in and the normalised copy is the arena's.
  - 6.4.15.6's comparison against a literal, where the operand that is not
    already a text is normalised so that a byte comparison answers the
    question that clause asks.

  Without the release each loop stops with `more string values are live at
  once than the string arena holds` long before it is done. }
program textarenaloop(output);

var a, b, t: utf8(64);
    s: string(64);
    i, n: integer;

begin
  a := 'héllo';
  b := ' wörld';

  t := a + b;
  n := 0;
  for i := 1 to 200000 do            { 13 bytes an iteration, joined }
    if a + b = t then n := n + 1;
  writeln(t, ' ', n:1);

  s := 'a string of some length';
  for i := 1 to 200000 do            { 23 bytes an iteration, normalised }
    t := s;
  writeln(t);

  n := 0;
  for i := 1 to 200000 do            { the literal, normalised each time }
    if t = 'a string of some length' then n := n + 1;
  writeln(n:1)
end.
