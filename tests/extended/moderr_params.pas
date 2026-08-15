{ ISO/IEC 10206:1991 6.11.1's module-heading takes a module-parameter-list in
  brackets, so the ')' that closes it has a context of its own. The parser
  stops at its first error, which is why each of these contexts is one file. }
module m(output;
export mi = (v);
var v: integer;
end;
end.
