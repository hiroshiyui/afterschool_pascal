{ The `string` schema, the ten string functions and the null-string literal are
  all ISO/IEC 10206:1991's. None of the names is a word-symbol — `string`,
  `length` and `trim` are required *identifiers*, so a valid ISO 7185 program
  may declare its own — and the refusals therefore happen where the names are
  resolved rather than in the lexer. The empty literal is the exception:
  §6.1.9 spells a character-string with *zero or more* string-elements where
  ISO 7185 requires one before the repetition, so the two languages differ
  over two apostrophes and nothing else.

  The bare schema-name is what says the required schema is not installed here:
  a compiler that declared it under both standards would report its
  discriminants missing rather than the name unknown. }
program StringIso(output);
var b: string;
    i: integer;
begin
  i := length(b) + index(b, b) + ord(eq(b, b));
  b := trim('  ') + substr('abcd', 2, 2);
  b := '';
  writeln(i:1, b)
end.
