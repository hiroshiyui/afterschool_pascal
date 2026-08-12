{ §6.8.6 is Extended Pascal's, and this is the program that says so.

  Getting this test right needs one piece of care that a green bar will not
  give you. The obvious ISO 7185 program to write is `mk(7, 8).x` with `mk`
  returning a record — but ISO 7185 §6.6.2 refuses a record *result*, so such a
  program dies at the result type and the selector is never reached. It would
  pass whatever the parser did, which is the fault ADR-0054 found in
  `constexpr_iso.pas` and the reason `constexpr_iso_fold.pas` exists.

  So the function here returns a **pointer**, which §6.6.2 allows. Everything
  about the program is a legal ISO 7185 program except the one thing under
  test: the `^` applied to a function-designator, which is §6.8.6.4's
  function-identified-variable and has no ISO 7185 production. Nothing else can
  produce the diagnostic. }
program FuncAccessIso(output);
type
  point = record x, y: integer end;
  pp = ^point;

var g: pp;

function alloc(a: integer): pp;
var t: pp;
begin new(t); t^.x := a; t^.y := a * 2; alloc := t end;

begin
  { Legal ISO 7185: the pointer is stored, and the selector applies to the
    variable. This half is what makes the failure below specific. }
  g := alloc(3);
  writeln(g^.y:1);

  { Not legal ISO 7185: a selector on a function-access. }
  writeln(alloc(4)^.y:1)
end.
