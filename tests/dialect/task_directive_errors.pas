{ Two refusals AP 6.7.8 and 6.7.8.2 require that an audit found missing
  (ADR-0365). Sema accumulates, so both are reported in one run.

  - "It shall not have a directive": `external` was refused and `forward`
    was not, `forward` being a directive too (6.1.4).
  - A task declared inside a task cleared the task rule on its way out, so
    every statement of the outer body after the inner declaration could name
    a global. The rule is restored, not cleared. }
program task_directive_errors(output);
var g: integer;

task A; forward;

task A;
begin end;

task Outer;
  task Inner;
  begin end;
  procedure Helper;
  begin
    g := 5
  end;
begin
  spawn Inner;
  g := g + 1;
  Helper
end;

begin
  g := 0;
  spawn A;
  spawn Outer;
  writeln(g)
end.
