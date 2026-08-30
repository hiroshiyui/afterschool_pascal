{ AP 6.7.3.10.5 (ADR-0266). The set of categories is small and closed, so a
  spelling that is not one of the four is a message about a category rather
  than a syntax error about the semicolon that never came. The parser commits
  on the *shape* -- an identifier followed by the word-symbol `type` -- and
  looks the spelling up afterwards, which is what makes that message
  writable. }
program p;
function Sum(Elem: hashable type; a, b: Elem): Elem;
begin Sum := a + b end;
begin writeln(Sum(1, 2):1) end.
