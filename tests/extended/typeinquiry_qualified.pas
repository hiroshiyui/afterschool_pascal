{ A variable-name admits **one** period, and only before an
  imported-interface-identifier (§6.5.1). The parser cannot tell that period
  from a field-designator's, so it consumes the first one either way and Sema
  asks the symbol — `typeinquiry_errors` carries that half. A *second* period
  is a field selection under any reading, which is what this file writes. }
program TypeInquiryQualified(output);
type rec2 = record g: integer end;
     rec = record f: rec2 end;
var r: rec;
    b: type of r.f.g;
begin
  r.f.g := 1; b := r.f.g; writeln(b:1)
end.
