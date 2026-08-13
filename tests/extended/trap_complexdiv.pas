{ ISO/IEC 10206:1991 §6.8.3.2: "a term of the form x/y shall be an error if y
  is zero", and table 3 gives `/` a complex operand — so the rule reaches the
  complex division too, and this is the arm ADR-0049 left to IEEE.

  It was left there for a reason that has since stopped being true. The comment
  said trapping here "would be the odd one out", real `/` not trapping either;
  now that one does, and this follows it rather than staying behind.

  The divisor is zero exactly when c² + d² is, and that number is already being
  computed for the quotient — so the check is one comparison on a value the
  lowering had anyway, not two on the parts. }
program TrapComplexDiv(output);
var a, b: complex;
begin
  a := cmplx(1.0, 2.0);
  b := cmplx(2.0, 0.0);
  writeln('re is ', re(a / b):1:1, ' im is ', im(a / b):1:1);
  b := cmplx(0.0, 0.0);
  writeln(re(a / b):1:4)
end.
