{ Annex B, and the one row where the two conformance modes do not say the same
  thing. ISO 7185 has no substring notation at all, so the parser stops at the
  `..` inside a subscript and says what it expected. Under Extended Pascal the
  notation exists for strings and Sema is what refuses it for an array -- see
  tests/extended/substring_refused.pas, which is the same program and a
  different message.

  Annex B had one column and claimed the Extended Pascal answer for both. It
  has two columns now; this pair is why. }
program substring_refused_iso(output);
var a: array [1..9] of integer;
begin
  writeln(a[2..4])
end.
