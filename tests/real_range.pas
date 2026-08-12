{ ISO 7185 §6.4.2.2 makes a real literal denote a value of the real-type, so
  one that denotes nothing the implementation has is an error. Until this file
  the integer path said so and the real path did not, and `1e400` compiled
  silently and printed INF.

  The rule is on the *decimal exponent*, not on a conversion: ADR-0025 keeps a
  real literal as its source text all the way into the IR precisely so that no
  conversion is needed, so the Pascal-hosted lexer has no `strtod` to consult.
  One rule both lexers can apply is worth more than an exact rule only one of
  them could. What that costs is the last decade before the boundary, which is
  why `9e308` is *not* on this list. }
program RealRange(output);
begin
  writeln(1e400);      { d=1, e=400 }
  writeln(1e309);      { the first exponent the rule refuses }
  writeln(1.5e999);
  writeln(12345678901234567890123456789012345678901234567890.0e260)
end.
