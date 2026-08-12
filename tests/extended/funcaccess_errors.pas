{ ISO/IEC 10206:1991 §6.8.6's NOTE: "A function-access is not equivalent to a
  variable-access. For example, a function-access may not be used as an actual
  variable parameter or as the record-variable in a with-statement."

  Nothing in this compiler enforces that sentence, and this file is the
  evidence that it holds anyway. Two of the refusals below come from the
  *grammar* — an assignment-statement's target and a with-statement's record
  are each a variable-access, and the parser has no production that lets a
  function-access be one, so the diagnostic is a parse error naming the token
  that could not follow. The other two come from `Sema::isDesignator`, which
  has answered `false` for a call since before this feature existed.

  §6.8.6.4's function-identified-variable is the exception in every one of
  these: `alloc(1)^` may be assigned, passed as a var parameter, read into and
  used as a with-record, because §6.5.1 makes it a variable-access. That half
  is in `funcaccess.pas`, which is where a legal program belongs.

  The parser stops at its first error, so a program can only carry one of the
  two grammar refusals; this file carries the Sema ones, which accumulate. }
program FuncAccessErrors(input, output);
type point = record x, y: integer end;
var n: integer;

function mk(a, b: integer) = r: point;
begin r.x := a; r.y := b end;

procedure bump(var k: integer);
begin k := k + 1 end;

begin
  { §6.9.4 b): an actual var parameter is threatened, so it must be a
    variable. A field of a result is not one — the storage is the call site's
    hidden slot, and writing to it would write to something the program has no
    way to read back. }
  bump(mk(1, 2).x);

  { §6.10.3's `read` needs somewhere to put what it read, for the same
    reason. }
  readln(mk(1, 2).y);

  { And the value is still a value: reading one is fine. }
  n := mk(1, 2).x + mk(3, 4).y;
  writeln(n:1)
end.
