{ What an implementation-declaration is refused for (ADR-0338, ADR-0340).
  Every refusal here is Sema's, and Sema accumulates, so one file reports
  them all. }
program traits_bad_impl(output);

type
  Point = record x: integer end;
  Colour = (red, green);
  digit = 1..9;

var notAType: integer;

trait Sortable;
  function Rank(p: Self; q: Self): integer;
end;

impl Sortable for Point;
  function Rank;
  begin Rank := p.x - q.x end;
end;

{ A second implementation of the pair the first already supplies. }
impl Sortable for Point;
  function Rank;
  begin Rank := 0 end;
end;

{ A subrange takes its host's implementation (ADR-0018), so one of its own
  could never be selected and is refused where it is written. }
impl Sortable for digit;
  function Rank;
  begin Rank := p - q end;
end;

{ A routine the trait does not declare. }
impl Sortable for Colour;
  function Rank;
  begin Rank := 0 end;
  function Missing(p: Self): integer;
  begin Missing := 0 end;
end;

{ A trait that is not one, a trait that is nothing, a type that is nothing,
  and a name that is not a type. }
impl NoSuchTrait for Point;
  function Rank;
  begin Rank := 0 end;
end;

impl Point for Colour;
  function Rank;
  begin Rank := 0 end;
end;

impl Sortable for NoSuchType;
  function Rank;
  begin Rank := 0 end;
end;

impl Sortable for notAType;
  function Rank;
  begin Rank := 0 end;
end;

{ 6.4.3.2's string is a schema and not a type, so it cannot carry one --
  which ADR-0338 names as the commonest key a map has. }
impl Sortable for string;
  function Rank;
  begin Rank := 0 end;
end;

begin
end.
