{ A module whose exported type is a variant record, so that ADR-0118's two
  rules both have something to apply to: Make writes a field (which activates
  a variant) and Peek reads one (which the dialect checks).

  It is the *pair* that this corpus is about. Each half is emitted at the
  access, so each belongs to whichever component contains the access -- and a
  component holding one half without the other is what ADR-0119 refuses. }
module Parts;

export Parts = (Outcome, ok, bad, Answer, Make, Peek);

type
  Outcome = (ok, bad);
  Answer = record
    case tag: Outcome of
      ok:  (num: integer);
      bad: (msg: string(16))
    end;

function Make(n: integer) = r: Answer;
function Peek(a: Answer): integer;

end;

function Make;
begin
  r.num := n              { activates ok }
end;

function Peek;
begin
  { reads num whatever the tag says -- guarded when this component is dialect,
    and guarded against a tag only the *other* component can have stored }
  Peek := a.num
end;

end.
