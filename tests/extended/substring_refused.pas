{ Annex B, and the one row where the two conformance modes do not say the same
  thing. §6.8.3.3 gives Extended Pascal a substring of a *string*, so `a[2..4]`
  parses and Sema is what refuses it for an array -- where ISO 7185 has no such
  notation and the parser stops at the `..`. tests/substring_refused_iso.pas is the
  same program under that standard, and its message is about a token.

  AP §6.8's extension of the notation to an array is the dialect feature; this
  is the mode that does not have it. }
program substring_refused(output);
var a: array [1..9] of integer;
begin
  writeln(a[2..4])
end.
