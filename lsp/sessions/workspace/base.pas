{ A workspace of three files, which is the smallest one that has all three
  shapes the server's import resolution has to answer (ADR-0238).

  This is the bottom of it: a module importing nothing, so opening it needs no
  imports at all and the answer is the empty prefix. It is here to prove the
  empty answer is *reached* rather than defaulted to -- a resolver that found
  nothing and a resolver that found nothing to add look alike from outside,
  and the middle file below is what tells them apart. }
module Base;

export Base = (Answer);

function Answer: integer;

end;

function Answer;
begin
  Answer := 42
end;

end.
