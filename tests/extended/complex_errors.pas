{ What the complex type may not do, and each rule's clause. }
program ComplexErrors(input, output);
var z: complex;
    r: real;
    i: integer;
    b: boolean;
    f: file of complex;
begin
  z := cmplx(1.0, 2.0);
  { §6.8.3.5 table 6: the four ordering operators take "any simple-type except
    complex-type". There is no order on the complex numbers. }
  b := z < z;
  b := z >= cmplx(0.0, 0.0);
  { §6.10.3.1 lists what write accepts — "integer-type, real-type, char-type,
    Boolean-type, or a string-type" — and complex is not among them. A program
    writes re(z) and im(z). }
  writeln(z);
  { ...and §6.10.1 gives read the same list, plus the string types. }
  read(z);
  { §6.4.6 c) widens *to* complex and never away from it: the conversion has no
    inverse, so re and im are the only way back to a real. }
  r := z;
  i := z;
  { §6.7.6.2: re, im and arg take a complex and nothing else. }
  r := re(1.0);
  r := arg(2);
  { §6.7.6.3: cmplx and polar take two real arguments. }
  z := cmplx(1.0);
  z := polar(1.0, 2.0, 3.0);
  { §6.7.6.4: an ordinal function has nothing to say about a complex. }
  i := ord(z);
  i := trunc(z);
  { §6.8.3.2 table 3 gives `pow` an integer right operand whatever the left. }
  z := z pow 2.0;
  { a file of complex is fine — §6.4.3.6 admits any component that is not and
    does not contain a file — so this one is the *write* to a text file above,
    not the component type }
  rewrite(f); write(f, z)
end.
