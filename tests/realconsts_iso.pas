{ ISO 7185 has no minreal, maxreal or epsreal, so the three names are ordinary
  identifiers there and nothing declares them. This file is the gate: with the
  --std test dropped from installPredefined, it compiles. }
program realconsts_iso(output);
begin
  writeln(maxreal);
  writeln(minreal);
  writeln(epsreal)
end.
