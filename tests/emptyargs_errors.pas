(* Pascal has no empty argument list.

       actual-parameter-list = '(' actual-parameter { ',' actual-parameter } ')'

  is ISO 7185 §6.7.3 and ISO/IEC 10206:1991 §6.7.3 alike, and both require at
  least one parameter. A parameterless call is the bare name — §6.8.2.2 makes
  reading a function identifier a call of it — so `f` and `f()` are not two
  spellings of one thing; there is only the one.

  Six copies of the argument loop wrote `if (!check(RParen))` around the list,
  which accepts the empty one, and `tests/extended/funcresult_bare.pas` had
  said in a comment that Pascal has no such thing while every one of the six
  took it. No program in the corpus had ever written a pair of empty
  parentheses, so no oracle disagreed with any of them (ADR-0072).

  The five spellings are one routine now, which is why one message serves them
  all. `write` keeps its own loop — §6.10.3's write-parameter is a value and an
  optional width, not an actual-parameter — and shares only this rule.

  Written with the other comment delimiters because §6.1.8's braces are the
  ones a grammar quotation needs, and a Pascal comment does not nest. *)
program emptyargs_errors(input, output);

var
  i: integer;

function f: integer;
begin
  f := 3
end;

procedure p;
begin
end;

begin
  { A function call, a procedure statement, and the three required procedures
    whose parameter list is optional in the first place — which is exactly why
    each needed saying: `readln` alone is legal and `readln()` is not the same
    program. }
  i := f();
  p();
  read();
  readln();
  writeln();
  writeln(i:1)
end.
