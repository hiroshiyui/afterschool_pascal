{ §6.8.6's NOTE, second half, and the example the NOTE itself gives: "a
  function-access may not be used ... as the record-variable in a
  with-statement."

  §6.8.3.10's record-variable-list is a list of variable-accesses, so this is
  the same grammar refusal `funcaccess_assign.pas` gets — and it has to be a
  grammar one. A `with` binds the record's *address* into a hidden frame slot
  and the binding outlives the statement's first line (ADR-0017); a result
  slot's address is the caller's frame and would survive it, so the rule is not
  protecting the program from anything it could not do. It is protecting the
  program from doing it by accident, which is what a syntax refusal is for. }
program FuncAccessWith(output);
type point = record x, y: integer end;

function mk(a, b: integer) = r: point;
begin r.x := a; r.y := b end;

begin
  with mk(1, 2) do
    writeln(x:1)
end.
