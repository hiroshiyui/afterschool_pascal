{ AP 6.7.8.2 says "in that task-declaration or in a block within it", and the
  first implementation compared a variable's owner with the task itself -- so
  a helper declared inside the task was refused its own parameter and its own
  local, which is the first thing a task of any size declares (ADR-0365, an
  audit's finding). Three things this case holds:

  - a procedure and a function declared inside a task name their own formals
    and locals, and the task's;
  - `writeln(output, ...)` inside a task is the spelling `writeln(...)` always
    was (6.10.3), and not a variable of another activation;
  - a task declared inside a task is checked under its own rule and then the
    outer body goes on being checked under the outer's -- the case beside
    this one holds the refusal, this one holds that the outer's own local is
    still accepted after the inner declaration. }
program task_nested_routine(output);
type ch = channel [4] of integer;
var c: ch; v, k: integer;

task Outer(out: ch; n: integer);
var acc, k: integer; tv: task;
  procedure Add(k: integer);
  var tmp: integer;
  begin
    tmp := k * n;
    acc := acc + tmp
  end;
  function Sq(k: integer): integer;
  var r: integer;
  begin
    r := k * k;
    Sq := r
  end;
  task Inner(out: ch; m: integer);
  var own: integer;
  begin
    own := m + 1;
    send(out, own)
  end;
begin
  acc := 0;
  Add(2);
  Add(Sq(3));
  writeln(output, 'acc ', acc:1);
  spawn tv := Inner(out, 99);
  wait(tv);
  k := acc;
  send(out, k);
  k := release(out)
end;

begin
  spawn Outer(c, 10);
  v := 0;
  while receive(c, k) do v := v + k;
  writeln(v:1)
end.
