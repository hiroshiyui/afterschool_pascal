{ The top two levels of tests/dialect/try_depth.pas's chain (ADR-0297). Both
  import DepthLow's productions and neither names ErrorCode's constants: a
  cause is carried up unchanged, and the one place the chain *adds* a reason
  of its own is Average's `errRange`. }
module DepthHigh;

export DepthHigh = (SumPairs, Average);

import PasError;
       DepthLow;

{ Level 2: two pairs, each read two levels down. }
function SumPairs(a, b: Pair) = r: IntResult;

{ Level 1: the mean of the two, refused as errRange when it is not a whole
  number -- so the chain has a failure at its top as well as at its bottom. }
function Average(a, b: Pair) = r: IntResult;

end;

function SumPairs;
begin
  r := try(ReadPair(a)) + try(ReadPair(b))
end;

function Average;
var sum: integer;
begin
  sum := try(SumPairs(a, b));
  if odd(sum) then r := errRange
  else r := sum div 2
end;

end.
