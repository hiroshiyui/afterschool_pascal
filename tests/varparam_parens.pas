{ ISO 7185 §6.6.3.3: "The actual-parameter shall be a variable-access."
  §6.5.1's variable-accesses are an entire-variable, a component-variable, an
  identified-variable and a buffer-variable -- a parenthesised expression is
  none of the four. So `p((x))` passes a *value* whose value happens to be x's,
  and there is nothing for a var parameter to establish a reference to.

  Nothing downstream could have seen this: the parser drops the brackets, so
  the node for `(x)` was the node for `x` and `p((x))` and `p(x)` produced
  identical trees. The node carries a flag now, and the check below is the only
  thing that reads it. }
program VarParamParens(output);

var
  x : integer;
  a : array [1..3] of integer;

procedure bump(var y : integer);
begin
  y := y + 1
end;

begin
  x := 0;
  a[1] := 0;
  bump((x));                    { an entire variable, bracketed }
  bump((a[1]));                 { a component-variable is no different }
  bump(x);                      { legal, and must not be reported }
  bump(a[1]);                   { legal }
  writeln(x:1, a[1]:1)
end.
