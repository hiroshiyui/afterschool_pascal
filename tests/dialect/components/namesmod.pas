{ A trait and nothing else, in a component of its own.

  A trait declared in one component and implemented in another for a type
  declared in a *third* is the shape the library will be in, and nothing
  exercised it (ADR-0411). Every other case here has the trait and the type
  in one place, which is the arrangement in which the fewest things can
  disagree. }
module Names;

export Names = (Naming, Tagged);

trait Naming;
  function Tag(protected var me: Self): integer;
end;

{ An ordinary exported routine beside the trait, so that the implementation
  in the client can call back into the component the trait came from. }
function Tagged(n: integer): integer;

end;

function Tagged;
begin Tagged := 100 + n end;

end.
