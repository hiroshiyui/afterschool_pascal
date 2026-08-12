{ The other side of tests/real_range.pas: what the decimal-exponent rule must
  *not* refuse. A literal at the top of the range, one whose mantissa is zero
  however it is scaled, and one whose exponent is negative — an exponent below
  zero can only underflow, and §6.4.2.2 leaves the value set
  implementation-defined, so a literal too small to represent denotes the
  nearest value there is rather than being an error. }
program RealEdges(output);
begin
  writeln(1e308 > 0.0);
  writeln(0e999:3:1, ' ', 0.0e999:3:1);
  writeln(1e-400:3:1);
  writeln(1.5e307 > 0.0)
end.
