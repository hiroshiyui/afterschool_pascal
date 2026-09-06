{ AP 6.4 (ADR-0338): a trait-declaration is a list of headings closed by `end`,
  and a heading is what a trait holds -- a body found where the next heading
  or the `end` should be is reported against the `end` that was expected. }
program p;
trait Ord;
  function Compare(a: Self; b: Self): integer;
  begin Compare := 0 end;
end;
begin end.
