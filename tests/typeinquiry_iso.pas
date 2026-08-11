{ A type-inquiry is ISO/IEC 10206:1991 §6.4.9 and nothing in ISO 7185, so under
  the default standard it is refused — and refused *as itself*, rather than as
  the "expected a type" the word `type` would otherwise get. Both of its words
  are reserved in ISO 7185, which is why the parser can recognise the construct
  in a language that does not have it and say so. }
program TypeInquiryIso(output);
var n: integer;
    m: type of n;
begin
  n := 1; m := n; writeln(m:1)
end.
