{ AP 6.4.4.1's pointer domain with type arguments is a dialect construct, and
  what a conformance mode says about one is conformance behaviour (ADR-0121,
  ADR-0154). ISO/IEC 10206:1991 6.4.4 admits nothing after the domain name, so
  the parenthesis is where both modes stop -- before any question about what
  the name denotes, which is why this names an ordinary type. Annex B row. }
program ptrtypedisc_refused_iso(output);
type Foo = integer;
var p: ^Foo(3);
begin end.
