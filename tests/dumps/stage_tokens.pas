{ --dump-tokens, and what the lexer has to spell.

  One of the three single-stage cases. Each names one flag and pins the
  documented behaviour that a --dump flag "stops at the stage it names": this
  one prints the token stream and nothing from the stages after it, however
  valid the rest of the program is.

  The banner is the part a reader will guess wrong. `=== tokens` belongs to
  --dump-all, which has three sections and so needs them separated; a
  single-stage flag has one section and writes it bare. Nothing checked either
  behaviour before tests/checks/coverage.py found the dump walkers unentered.

  The content is lexical on purpose -- every literal form, both comment
  delimiters, and the alternative representations §6.1.9 requires. }
program lex(output);
const
  dec = 100;
  neg = -7;
  txt = 'it''s';
type
  row = array (.1 .. 2.) of integer;   (* §6.1.9: (. .) is [ ] *)
var
  r: row;
  y: real;
begin
  y := 1.5e2;                          { a real with an exponent }
  r(.1.) := dec + neg;
  writeln(r(.1.) : 3, ' ', y : 6 : 1, ' ', txt)
end.
