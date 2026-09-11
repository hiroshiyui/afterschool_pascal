{ AP 6.7.10 (ADR-0338, ADR-0410): an implementation-declaration has two forms
  and `for` is the whole of what separates them -- `impl T;` gives a type
  routines of its own, and `impl Tr for T;` implements a trait for it. So the
  `for` left out of the second is no longer a syntax error: it is the *first*
  form, naming a trait where a type belongs, and Sema is what can say so.

  **This case was a parse error and is a Sema one, which is why it moved
  files rather than being struck.** A case that only lost a claim would be a
  case asserting less than it did; what it asserts now is the thing a reader
  who forgot the word actually needs, which is that both forms exist and which
  one they wrote. }
program p;
trait Ord;
  function Compare(a: Self; b: Self): integer;
end;
impl Ord;
  function Compare;
  begin Compare := 0 end;
end;
begin end.
