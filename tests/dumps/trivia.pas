{ 6.1.8's comments, which the lexer discarded until ADR-0279 and now records
  when something asks. This case is the dump of them, so what it exercises is
  the *shapes a comment takes* and not what any of them says. }
program trivia(output);
(* a star-paren comment, which 6.1.8's NOTE 1 says may be closed by a brace
   and is here }
{ ...and the other way round, which is the same production read the same way:
  which delimiter closes a commentary does not depend on which opened it, and
  ADR-0073 is the record of that being got wrong *)
var
  i: integer;   { trailing a declaration, on its line }

  { standing on a line of its own, after a blank one }
  j: integer;

begin { after a begin }
  i := 1; j := 2;
  writeln(i { inside an expression } + j:1);
  { two in a row }
  { and the second of them }
  writeln('done')
  { before the end }
end.
