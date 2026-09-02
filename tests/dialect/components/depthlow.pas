{ The bottom two levels of a four-deep chain of fallible routines, for
  tests/dialect/try_depth.pas (ADR-0297). Every routine here answers a
  production of PasError's `Fallible` and propagates with AP 6.8.9's `try`,
  which is the shape a program that may fail takes; the case above records
  what it reads like. }
module DepthLow;

export DepthLow = (Pair, IntResult, ReadDigit, ReadPair);

import PasError;

type
  Pair = string(2);
  { Named here the way every library module names its production; it is the
    same type as PasParse's IntResult, 6.4.7 interning per tuple, and neither
    module needs to know about the other. }
  IntResult = Fallible(integer);

{ Level 4: the one routine that can *originate* a failure. }
function ReadDigit(c: char) = r: IntResult;

{ Level 3: two digits, each through `try`. A second failing digit is never
  reached -- the first `try` has already left. }
function ReadPair(s: Pair) = r: IntResult;

end;

function ReadDigit;
begin
  if (c >= '0') and (c <= '9') then r := ord(c) - ord('0')
  else r := errSyntax
end;

function ReadPair;
begin
  r := 10 * try(ReadDigit(s[1])) + try(ReadDigit(s[2]))
end;

end.
