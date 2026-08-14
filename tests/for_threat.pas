{ ISO 7185 §6.8.3.9:

    Neither a for-statement nor any procedure-and-function-declaration-part of
    the block that closest-contains a for-statement shall contain a statement
    threatening the variable denoted by the control-variable of the
    for-statement.

  ISO/IEC 10206:1991 §6.9.3.9.1 is the same sentence with a cross-reference to
  §6.9.4 spliced into it, and §6.9.4 is the list this compiler already walks
  for a protected parameter (ADR-0046). Every entry on it that an ordinal
  entire-variable can meet is here: an assignment, an actual var parameter, a
  read, and a nested for-statement -- the last through the equivalent program
  fragment §6.8.3.9 gives, whose own `v := succ(v)` is the threat.

  The fifth is the one no reading of "inside the loop" catches. `hidden` is
  threatened by a procedure that is never called, in the *declaration* part of
  the block the loop is in, and the clause names that part in the same breath
  as the for-statement. BSI's DEV224 puts such a threat behind `if 1 = 0`
  precisely so that no optimiser can make it go away: the rule is about the
  program's text and not about what it does.

  The legal shapes matter as much as the violations, and they come first.
  `outer` threatens a variable that is nobody's control variable. `sibling`'s
  own `k` is not the `k` the program loops over -- a check written against the
  spelling rather than the symbol reports both, and the BSI suite has twenty
  programs that differ in exactly that way. Neither may be reported. }
program ForThreat(output);
var i, j, k, hidden : integer;
    f : text;

procedure eat(var n : integer);
begin
  n := 0
end;

{ Legal: `j` is threatened, and `j` is nobody's control variable. }
procedure outer;
begin
  j := 1;
  eat(j)
end;

{ Legal: this `k` is this block's, not the program's. }
procedure sibling;
var k : integer;
begin
  k := 1;
  eat(k)
end;

{ §6.8.3.9's procedure-and-function-declaration-part clause. Never called. }
procedure nestedThreat;
begin
  if 1 = 0 then hidden := hidden
end;

begin
  j := 0;
  rewrite(f);
  writeln(f, 5);
  reset(f);
  outer;
  sibling;
  for i := 1 to 10 do
  begin
    j := j + 1;
    i := i + 1;
    eat(i);
    read(f, i);
    for i := 1 to 2 do
      j := j + 1
  end;
  { Legal: nothing threatens `k` but `sibling`'s own local of that spelling. }
  for k := 1 to 10 do
    j := j + 1;
  for hidden := 1 to 10 do
    j := j + 1
end.
