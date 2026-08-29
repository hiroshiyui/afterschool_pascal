{ The middle component, and the reason this case is about *transitivity*: the
  program imports this one and never names the one below it, so what reaches
  the compiler through the search path is a chain and not a list (ADR-0244).

  Its activation must follow bynamebase's, which is what its own output says. }
module bynamemid;

export bynamemid = (midTally, midBump);

import StandardOutput; bynamebase;

var
  midTally: integer;
procedure midBump(n: integer);
end;

procedure midBump;
begin
  baseBump(n);
  midTally := midTally + baseTally
end;

to begin do
  begin
    writeln('mid activated, base tally = ', baseTally:1);
    midTally := 0
  end;

end.
