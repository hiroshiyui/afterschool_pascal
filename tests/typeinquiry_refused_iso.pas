{ AP 6.4.9 (ADR-0215) widens the type-inquiry-object to §6.5.1's whole
  variable-access. ISO 7185 has no type-inquiry at all, so its parser stops one
  token earlier than Extended Pascal's and names the standard that does have
  one — the same two-stage answer `typeparam_refused_iso` gets, and for the
  same reason: the dialect's construct is spelled inside a construct the older
  standard does not have. Annex B row. }
program typeinquiry_refused_iso(output);
var a: array [1..3] of integer;
    b: type of a[1];
begin
  a[1] := 1; b := a[1]; writeln(b:1)
end.
