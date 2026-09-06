{ `Self` shall stand only as a parameter's whole type or as a result type, and
  the refusal is at the *trait* (ADR-0339). Left to the implementation the
  message would arrive once per impl, in the impl's own source, and would
  describe a procedural parameter's parameter list to a reader who wrote
  neither. }
program traits_self_inside(output);

trait Bad;
  function Take(xs: array of Self): integer;
  function Both(xs: array of Self; ys: array of Self): integer;
end;

trait AlsoBad;
  function Give(n: integer): integer;
  function Mixed(a: Self; b: array of Self): Self;
end;

begin
end.
