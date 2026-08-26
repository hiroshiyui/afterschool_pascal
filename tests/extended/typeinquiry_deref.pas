{ §6.5.1's identified-variable — `p^` — is a variable-access and not a
  variable-name, so §6.4.9 does not admit it either. Its own file, the parser
  stopping at the first error; `typeinquiry_component` has the reasoning. }
program TypeInquiryDeref(output);
var p: ^integer;
    b: type of p^;
begin
  new(p); p^ := 1; b := p^; writeln(b:1)
end.
