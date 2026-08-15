{ ISO/IEC 10206:1991 6.4.2.4 makes a subrange-bound a constant-expression, so
  the '..' is no longer a fixed number of tokens from the start of the denoter
  and the parser scans for one at bracket depth zero (ADR-0054). Finding one
  is not the same as its being where the first bound ends: two constants
  written with nothing between them put a token in the way, which is the one
  shape that reaches this message.

  Under ISO 7185 a bound is a single `constant` and the scan is a two-token
  lookahead, so the '..' is always immediately next and this branch is
  unreachable there. }
program SubrangeBoundMissing(output);
type t = 1 2..3;
var x: t;
begin
  x := 1
end.
