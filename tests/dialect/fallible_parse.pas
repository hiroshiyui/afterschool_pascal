{ AP 6.4.13's `!` takes a type-denoter on each side. Its own file because the
  parser stops at its first error, and the one thing this pins is the token's
  spelling in a diagnostic -- the only path that writes `!` as a token name
  (ADR-0176). }
program fallible_parse(output);
type X = ! integer;
begin
  writeln(1)
end.
