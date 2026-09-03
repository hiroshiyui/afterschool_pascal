{ A module in a directory of its own, so that the client beside it cannot be
  compiled by naming files: what places it is the sidecar's directory list. }
module Greeting;
export Greeting = (Answer);
function Answer: integer;
end;
function Answer;
begin
  Answer := 42
end;
end.
