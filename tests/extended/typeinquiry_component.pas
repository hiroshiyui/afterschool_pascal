{ §6.4.9: `type-inquiry-object = variable-name | parameter-identifier`, and
  §6.5.1's variable-name is `[ imported-interface-identifier '.' ]
  variable-identifier` — a *name*, never one of the other variable-accesses.
  So an indexed one is not admitted, however natural `type of a[1]` looks to
  someone reaching for the element type of an array.

  The parser stops at the first thing it cannot make sense of, so each spelling
  that is refused there carries its own file: this one, `typeinquiry_deref` and
  `typeinquiry_qualified`. }
program TypeInquiryComponent(output);
var a: array [1..3] of integer;
    b: type of a[1];
begin
  a[1] := 1; b := a[1]; writeln(b:1)
end.
