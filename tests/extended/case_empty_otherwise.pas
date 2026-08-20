{ An empty case-list-element may abut `otherwise` (ISO/IEC 10206:1991 6.9.3.5
  and 6.9.2.1).

  6.9.3.5 writes the case-statement's completer as

      [ [ ';' ] case-statement-completer ]

  and the INNER bracket is what this file is about: the separator before
  `otherwise` is optional, so a case-list-element whose statement is the empty
  one may be followed by `otherwise` with nothing at all between them. The
  clause's own Example 1 omits the separator, though with a non-empty arm.

  This compiler refused it -- `expected a statement, found 'otherwise'`. The
  empty statement's follow-set in ParseStatement had four tokens, `;`, `end`,
  `else` and `until`, which is complete for ISO 7185 and one short for the
  standard that has a completer. Both front ends had the same four, so the
  differential oracle compared two identical refusals and agreed (ADR-0034's
  shape, from the inside).

  It was found by a specification audit: an independent reader computed the
  follow-set from 6.9's productions and reported that a document here listed
  four tokens where the standard admits five. The reader's own probe used a
  NON-empty arm before `otherwise`, which has always worked -- the refusal is
  reachable only when the arm is empty, which is what makes this a case worth
  writing rather than a comment worth correcting.

  Under ISO 7185 none of this exists: `otherwise` is an ordinary identifier
  there and a case-statement has no completer, so the token never reaches the
  test. That is why the fix needs no guard on the standard. }
program CaseEmptyOtherwise(output);
var i: integer;
begin
  { the arm is empty and `otherwise` follows it directly }
  i := 1;
  case i of 1: otherwise writeln('unreached') end;
  writeln('empty arm, no separator');

  { two arms, the second empty }
  i := 2;
  case i of 1: writeln('unreached'); 2: otherwise writeln('unreached') end;
  writeln('empty second arm');

  { and the separator still being optional after a *non-empty* arm, which
    always worked and is here so a fix in the wrong direction fails too }
  i := 9;
  case i of 1: writeln('unreached') otherwise writeln('completer ran') end;

  { the completer's own statement-sequence may be empty as well, both with a
    separator and without }
  i := 9;
  case i of 1: writeln('unreached') otherwise end;
  case i of 1: writeln('unreached') otherwise ; end;
  writeln('empty completer')
end.
