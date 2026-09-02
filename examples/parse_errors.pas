{ Error handling, both ways: a fallible result read with `try`, and read
  with an accessor that supplies a default.

  Turbo Pascal's Val hands back an error position and leaves the check to
  you. Here a routine that can fail answers a fallible type, `integer !
  ErrorCode` (AP 6.4.13): `r.ok` says which arm was written, `r.val` is the
  value, `r.cause` the reason, and reading the arm that was not written
  stops the program -- so a forgotten check is a halt, not a stale value.
  Uses PasParse (ParseInt), PasError (ErrorText, ValueOr) and PasText (Split). }
program parse_errors(output);

import PasError; PasParse; PasText;

{ Sum a comma-separated list. `try(x)` is x's value where x succeeded; where
  it did not, the cause becomes *this* function's result and the function
  returns at once (AP 6.8.9). It is `if not r.ok then exit(r.cause)`, written
  by the language, once, at the point of use. }
function SumOf(list: TextLine): IntResult;
var fields: Parts(16); count, k, total: integer;
begin
  Split(list, ',', fields, count);
  total := 0;
  for k := 1 to count do
    total := total + try(ParseInt(fields[k]));
  SumOf := total
end;

procedure Report(list: TextLine);
var r: IntResult;
begin
  r := SumOf(list);
  if r.ok then writeln('sum of [', list, '] = ', r.val:1)
  else writeln('sum of [', list, '] failed: ', ErrorText(r.cause))
end;

begin
  Report('1,2,3');
  Report('10, 20, 30');          { ParseInt ignores the blanks }
  Report('4,x,6');               { errSyntax, and 6 was never looked at }
  Report('1,99999999999');       { errRange: past maxint }

  { The other way round: the caller has a default and does not care why. }
  writeln('width = ', ValueOr(ParseInt('80'), 72):1);
  writeln('width = ', ValueOr(ParseInt('wide'), 72):1)
end.
