{ ADR-0137's other module: everything parts.pas is, except the one thing that
  makes the modes differ. Its interface exports a record type -- so the walk
  has to look inside something rather than passing trivially -- and that record
  has no variant-part at all.

  So no access to it can emit ADR-0118's check under any mode, its object code
  is the same under --std=extended and --std=afterschool, and a dialect program
  may link the conformance-mode translation of it. That is what lets `lib/`'s
  six conforming modules be used from the language that contains Extended
  Pascal. }
module Plain;

export Plain = (Pair, Nearer, Total);

type
  Pair = record lo, hi: integer end;

function Nearer(p: Pair): integer;
function Total(p: Pair): integer;

end;

function Nearer;
begin
  if abs(p.lo) <= abs(p.hi) then Nearer := p.lo else Nearer := p.hi
end;

function Total;
begin Total := p.lo + p.hi end;

end.
