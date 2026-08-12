{ §6.8.6's NOTE, first half, refused by the grammar rather than by a rule.

  An assignment-statement's target is a variable-access (§6.8.2.2), and §6.5.1
  lists what those are: an entire-variable, a component-variable, an
  identified-variable, a buffer-variable, a substring-variable, and a
  function-identified-variable. A record-function-access is not on the list, so
  there is no production that reaches this and the diagnostic names the token
  that could not follow a procedure-statement.

  That is why it is in a file of its own: the parser stops at its first error,
  so this refusal and `funcaccess_with.pas`'s cannot share one. }
program FuncAccessAssign(output);
type point = record x, y: integer end;

function mk(a, b: integer) = r: point;
begin r.x := a; r.y := b end;

begin
  mk(1, 2).x := 5
end.
