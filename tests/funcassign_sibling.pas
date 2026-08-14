{ ISO 7185 §6.8.2.2: "The function-block associated (see 6.6.2) with the
  function-identifier of an assignment-statement shall contain the
  assignment-statement."

  *Contain*, not be. A procedure nested inside `f` may write `f`'s result --
  it reaches it through the static chain exactly as it reaches any enclosing
  variable -- so the test is a walk up the owner chain and not `= currentProc`.
  `inner` below is the legal shape, and it is here so that the walk is not
  "simplified" into a comparison.

  What is refused is a *sibling*: `wrong` is not contained by `target`'s block,
  so writing `target` there names a result variable that this activation has no
  business filling in. ADR-0055 stated this as a deliberate non-enforcement and
  it is one no longer.

  Only one diagnostic comes out per assignment. Once §6.8.2.2 has reported the
  target, "the left side of an assignment must be a variable" is a consequence
  of that fault and not a second one. }
program FuncAssignSibling(output);

function target: integer;

  { Legal: nested inside target, so target's block contains this statement. }
  procedure inner;
  begin
    target := 7
  end;

begin
  target := 1;
  inner
end;

function wrong: integer;
begin
  target := 2;        { §6.8.2.2: not this block's function }
  wrong := 3
end;

begin
  writeln(target:1, wrong:1)
end.
