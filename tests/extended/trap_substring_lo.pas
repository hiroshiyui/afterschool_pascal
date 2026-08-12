{ §6.5.6, the bound that is less than 1: "It shall be an error if
  the value of an index-expression ... is less than 1".

  Its own file, because a program stops at the first runtime error and
  `trap_substring.pas` already spends itself on the i > j clause. Three
  conditions, three programs — and each one had a mutation survive a green
  suite until it was written, because the check is one `if` with three
  disjuncts and a corpus that exercises one of them proves nothing about the
  other two. }
program TrapSubstringlo(output);
var s: packed array [1..6] of char;
begin
  s := 'abcdef';
  writeln('[', s[1..6], ']');
  writeln('[', s[0..3], ']')
end.
