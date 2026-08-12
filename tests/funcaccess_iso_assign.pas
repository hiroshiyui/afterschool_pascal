{ The statement form of the same gate, and it needs a file of its own because
  the parser stops at its first error.

  This one is worth more than it looks. Telling `alloc(3)^.x := 1` from a
  procedure-statement takes a scan to the matching `)` — the token that decides
  is not a fixed distance away — and that scan has its own test of which
  standard is being compiled. A version that scanned unconditionally would
  accept this program: the parser would build the assignment, and Sema, which
  is told nothing about function-accesses at all, would raise no objection. So
  the refusal here is the only thing anywhere that holds the statement form to
  ISO 7185, and `funcaccess_iso.pas` does not cover it. }
program FuncAccessIsoAssign(output);
type
  point = record x, y: integer end;
  pp = ^point;

function alloc(a: integer): pp;
var t: pp;
begin new(t); t^.x := a; t^.y := a * 2; alloc := t end;

begin
  alloc(3)^.x := 1
end.
