{ §6.7.6.7's three error conditions for substr, reached at fold time.

  "It shall be an error if the value of i is less than or equal to 0. It shall
  be an error if the value of j is less than 0. It shall be an error if the
  value of (i)+(j)-1 is greater than the length of the value of s."

  Since ADR-0226 a substr over constants is folded, so these are compile-time
  errors rather than traps -- §5.1 f) 1) permits reporting "the possibility of
  the dynamic-violation during preparation of the program", which is what the
  substring-constant fold beside this has always done for §6.5.6.

  Sema accumulates, so one run reports all of them.

  **The last one is the reason the third condition is not written as a sum.**
  `i + j - 1` with both at maxint overflows, and this compiler's own integer
  arithmetic traps on overflow (ADR-0014) -- so forming it would stop the
  compiler instead of reporting the error the clause names. It is asked as
  `j > n - i + 1`, where `n - i + 1` cannot overflow once i is known positive. }
program ConstExprStringErrors(output);

const
  low   = substr('abcde', 0, 2);
  neg   = substr('abcde', 2, -1);
  past  = substr('abcde', 3, 9);
  after = substr('abcde', 7, 0);
  huge  = substr('abcde', maxint, maxint);

begin
  writeln(low, neg, past, after, huge)
end.
