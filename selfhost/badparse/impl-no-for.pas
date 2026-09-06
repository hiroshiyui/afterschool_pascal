{ AP 6.7 (ADR-0338): an implementation-declaration names the trait and then
  `for` and the type. `impl` is recognised by position -- the word and an
  identifier -- so by this token the parser has committed, and what is missing
  is named rather than reported as an unexpected semicolon. }
program p;
trait Ord;
  function Compare(a: Self; b: Self): integer;
end;
impl Ord;
  function Compare;
  begin Compare := 0 end;
end;
begin end.
