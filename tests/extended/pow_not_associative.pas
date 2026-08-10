{ ISO/IEC 10206:1991 has

    factor = primary [ exponentiating-operator primary ]

  which admits one operator and not a chain. 6.8.1 says operators of one
  precedence associate to the left, but the syntax leaves nothing here for that
  rule to apply to -- so a chain is not a sentence of the language, and picking
  a grouping for it would be inventing an answer that neither reading of the
  standard supports.

  This is a parser message, so it would belong in selfhost/badparse/ with the
  rest -- except that that corpus is compiled as ISO 7185, where `**` is
  refused by the lexer and the parser never runs at all. A message reachable
  under only one standard has to be tested under it. }
program PowNotAssociative(output);
var i: integer;
begin
  i := 2 ** 3 ** 4;
  writeln(i:1)
end.
