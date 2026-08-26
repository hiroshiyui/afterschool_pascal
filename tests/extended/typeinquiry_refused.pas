{ AP 6.4.9 (ADR-0215) widens the type-inquiry-object to §6.5.1's whole
  variable-access. What a conformance mode says about a dialect construct is
  conformance behaviour (ADR-0121, ADR-0154), so both front ends have an
  opinion here and difftest compares them. Annex B row.

  §6.4.9's own object is `variable-name | parameter-identifier`, and §6.5.1's
  variable-name is `[ imported-interface-identifier '.' ] variable-identifier`
  — a name. The other five variable-accesses are outside the clause, which is
  why the dialect having them is a feature and not a fix.

  The parser stops at its first error, so the other spellings carry their own
  files: `typeinquiry_deref`, `typeinquiry_qualified` and `typeinquiry_field`. }
program typeinquiry_refused(output);
var a: array [1..3] of integer;
    b: type of a[1];
begin
  a[1] := 1; b := a[1]; writeln(b:1)
end.
