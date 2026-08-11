{ `complex` and its five functions are ISO/IEC 10206:1991's, and none of their
  names is a word-symbol — a valid ISO 7185 program may define a type called
  `complex` or a function called `re`. So this is not a lexical question and the
  lexer cannot answer it: the refusal happens where the name is resolved, which
  is why the message names the feature rather than the identifier. }
program ComplexIso(output);
var z: complex;
    r: real;
begin
  z := cmplx(1.0, 2.0);
  r := re(z);
  writeln(r:3:1)
end.
