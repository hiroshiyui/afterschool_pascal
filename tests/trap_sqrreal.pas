{ §6.6.6.2, D.32: "sqr(x) computes the square of x. It is an error if such a
  value does not exist."

  For an integer that is the overflow `checkedArith` has reported since
  ADR-0014. For a real it is an infinity where the operand was finite, and
  this is the *only* real operation the standard names this way: §6.7.2.2
  makes the accuracy of `+ - * /` implementation-defined rather than making
  their overflow an error, so `sqr` is a check and `x * x` written out is not.
  ISO/IEC 10206:1991's D.57 says the same for both types in one sentence.

  The magnitude is what is tested, not the value: `sqr(-1e200)` is `+inf` too,
  and an operand that was already infinite is D.74's error — using a value the
  type does not have — rather than this one. }
program TrapSqrReal(output);
var x: real;
begin
  x := 3.0;
  writeln('sqr(3) is ', sqr(x):1:1);
  x := -1.0e200;
  writeln(sqr(x):1:1)
end.
