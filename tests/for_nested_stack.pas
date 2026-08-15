{ A for statement inside another loop must not claim storage on every
  iteration of the loop around it.

  ISO 7185 6.8.3.9 says the limit is evaluated once, and this compiler used to
  implement "once" by storing it into an alloca and loading it back each time
  round. The emitter is sequential and cannot go back to the entry block
  (ADR-0025), so that alloca was written wherever emission had reached -- which
  for a for-statement nested in a loop is inside that loop. Each outer
  iteration then claimed another 16 bytes that nothing reclaimed until the
  procedure returned.

  Nothing observable is wrong with the *answer*, which is why no golden caught
  it: the program computes the same sum either way and simply runs out of
  stack first. The two things that make this file able to fail are therefore
  not in the Pascal at all --

    for_nested_stack.opt   -O0, because at -O2 LLVM hoists an alloca whose
                           address does not escape and the leak disappears
    run_test.sh            bounds the stack at 8 MB, as it bounds the
                           descriptor table, so "runs out" is reachable

  -- and removing either one makes this a test that passes for no reason.

  2,000,000 iterations against an 8 MB stack is about four times what it takes
  to exhaust it at 16 bytes an iteration; the loop body is trivial, so it costs
  a fraction of a second. The `for` is written over a subrange so that the
  bound check of 6.8.3.9 is emitted too, which is the shape that creates the
  most blocks before the limit is reached. }
program ForNestedStack(output);
var
  i: 0..10;
  n, s: integer;
begin
  s := 0;
  n := 0;
  while n < 2000000 do
    begin
      for i := 1 to 2 do s := s + 1;
      n := n + 1
    end;
  writeln('sum ', s:1)
end.
