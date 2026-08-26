{ AP 6.7.3.5's type parameter is a dialect construct, and what a conformance
  mode says about one is conformance behaviour (ADR-0121, ADR-0154) -- so both
  front ends have an opinion here and difftest compares them. Annex B row. }
program typeparam_refused_iso(output);
procedure P(T: type; var a: T);
begin a := a end;
begin end.
