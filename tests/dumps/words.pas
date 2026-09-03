{ ADR-0301. The vocabulary, which is a property of *this compiler* and not of
  the source it was handed: every word-symbol 6.1.2 reserves and every required
  identifier 6.2.2.10 puts in a region enclosing the program.

  So this program is the smallest one that parses, and it is deliberately not
  a program *about* anything: what the golden beside it holds is the answer,
  and the answer would be the same for any source that reaches Sema.

  Three things it pins that nothing else here can. `restricted` is ten
  characters and `kwLit` is nine, so the lexer cannot hold it in the table with
  the other forty-five and it is written out on its own -- a reader dropping
  that line loses a word-symbol and no other oracle would say so. The twelve
  required *procedures* are not symbols in any scope (ADR-0097), so they come
  from `RequiredProcName`, which `IsRequiredName` reads too -- one list, two
  readers. And everything else is the outermost scope walked at the one moment
  it holds the required identifiers and nothing the source declared. }
program words;
begin
end.
