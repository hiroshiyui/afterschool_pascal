{ A `var` parameter a body never writes through could say so, and ADR-0283 is
  the warning that says which ones. It is ADR-0272's fourth and the first
  whose answer is a property of the *component* rather than of the routine.

  6.7.3.1 spells it `protected var`. What makes the advice exact rather than a
  guess is that the compiler already owns the test: 6.5.1 forbids a statement
  to threaten a variable-access closest-containing a protected
  variable-identifier, 6.9.4 lists the six ways to threaten one, and the
  compiler records each of them as it is seen. So "never threatened" is
  precisely the condition under which adding the word still compiles -- not a
  reading of what the body appears to do.

  This program prints the same thing whatever is warned about: every warning
  here is a remark about a program that compiles and runs. }
program protected_hint(output);

import protected_helper;

type ptr = ^integer;

var total: integer;

{ --- warned about: nothing writes through them ------------------------- }

{ One parameter of a group of one. }
function Doubled(var n: integer): integer;
begin
  Doubled := n * 2
end;

{ A whole group, where every name in it is unwritten -- the shape that takes
  the word once for all three. They are on one line and so are distinguished
  only by column, which is what the report has to sort on. }
function Sum3(var a, b, c: integer): integer;
begin
  Sum3 := a + b + c
end;

{ --- not warned about, and each for a different reason ------------------ }

{ Written through, which is what a var parameter is for. }
procedure Fill(var n: integer);
begin
  n := 7
end;

{ Already protected: there is nothing to advise. }
function Tripled(protected var n: integer): integer;
begin
  Tripled := n * 3
end;

{ 6.4.1 makes a pointer unprotectable, so advising the word here would be
  advising something the compiler refuses. `Protectable` is the compiler's own
  predicate and the warning asks it. }
function Deref(var p: ptr): integer;
begin
  Deref := p^
end;

{ Threatened without being assigned: 6.9.4 counts passing a variable as an
  actual variable parameter, so `n` is written through Fill and the warning
  must not fire. A test of the *clause* and not of assignment. }
procedure ViaVarActual(var n: integer);
begin
  Fill(n)
end;

{ A nested procedure's write counts as the outer parameter's: the bodies are
  walked before the enclosing statement part, so the threat is recorded before
  anything asks. }
procedure ViaNested(var n: integer);
  procedure Inner;
  begin
    n := 99
  end;
begin
  Inner
end;

{ A nested routine's body is checked *before* the block that declares it, so
  its candidate is recorded first and the two arrive in the reverse of source
  order. The report is sorted, so `outer` is named before `inner` -- which is
  the only shape in this tree that makes the sort move anything, and without a
  case for it the comparison would be a branch nothing takes. }
function Outer(var ov: integer): integer;
  function Inner(var iv: integer): integer;
  begin
    Inner := iv + 1
  end;
var scratch: integer;
begin
  { through a local, because handing `ov` to `Inner` would threaten it --
    6.9.4 counts an actual variable parameter, and `Inner`'s formal is not
    protected. Two candidates are wanted here, not one. }
  scratch := ov;
  Outer := Inner(scratch)
end;

{ --- the whole-component guard ----------------------------------------- }

{ Never written through, and still not advised: it is passed as a procedural
  actual below, and 6.6.3.6 makes the formal-parameter-lists congruous with
  `protected` in them -- so the word would refuse the very call that passes
  it. The call is written *after* this declaration on purpose: at the point
  the body is checked nothing knows the routine will travel, which is the
  whole reason the answer is deferred to the end of the compilation. }
function Passed(var n: integer): integer;
begin
  Passed := n + 1
end;

function Apply(function F(var q: integer): integer; var arg: integer): integer;
begin
  Apply := F(arg)
end;

begin
  total := 0;
  total := total + Doubled(total) + 2;
  total := total + Sum3(total, total, total);
  Fill(total);
  total := total + Tripled(total);
  ViaNested(total);
  total := total + Outer(total);
  total := total + Apply(Passed, total);
  total := total + Shown(total);
  writeln('total ', total:1)
end.
