{ A trait is a symbol kind and not a type kind (ADR-0338), so its name denotes
  nothing in a type-denoter -- and `Self` denotes nothing outside an
  implementation, which is what makes the spelling need no rule of its own.

  Every position a type-denoter may stand in, in one program: Sema accumulates,
  so one file reports all of them. }
program traits_not_a_type(output);

trait Sortable;
  function Rank(p: Self; q: Self): integer;
end;

type
  Alias = Sortable;
  Rec = record f: Sortable end;
  Arr = array [1..3] of Sortable;
  PtrDom = ^Sortable;
  Setty = set of Sortable;
  Ranged = record g: Self end;

var
  v: Sortable;
  w: Self;

function ResultType: Sortable;
begin ResultType := v end;

procedure Formal(a: Sortable; b: Self);
begin end;

begin
end.
