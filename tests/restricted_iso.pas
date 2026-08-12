{ §6.4.2.5 is Extended Pascal's, and `restricted` is a word ISO 7185 does not
  reserve — so under `--std=iso7185` it is an ordinary identifier, and this
  program is a legal ISO 7185 program that uses it as one.

  That is the whole test, and it is the *opposite* shape from ADR-0056's ISO
  gate: there the notation had to be refused, here the word has to keep
  working. ADR-0033's reason for making the standard a property of the source,
  made concrete for the seventh time. }
program RestrictedIso(output);
var restricted: integer;
begin
  restricted := 41;
  restricted := restricted + 1;
  writeln(restricted:1)
end.
