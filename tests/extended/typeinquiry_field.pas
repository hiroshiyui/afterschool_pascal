{ The one spelling of a component the parser cannot refuse: §6.5.1's
  variable-name admits a qualifier before an imported-interface-identifier, and
  the parser has one production for that and for a field-designator. So `r.f`
  is consumed whole and Sema asks the symbol — ask the symbol, not the syntax.
  Under --std=afterschool it is a field selection and the program runs, which
  is why this case is in tests/checks/containment_exceptions.txt. }
program TypeInquiryField(output);
type point = record x, y: integer end;
var a: point;
    b: type of a.x;
begin
  a.x := 1; b := a.x; writeln(b:1)
end.
