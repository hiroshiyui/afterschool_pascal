{ Annex B of doc/afterschool-pascal-spec.md, the ISO 7185 half: `external` is a
  dialect feature (ADR-0121) and this mode names it and says which mode has it.
  §6.1.4 makes a directive an identifier in the one position it may occupy, so
  the word is an ordinary identifier here and nothing else moved -- what is
  refused is this construct, not this spelling.

  The message is the same under both conformance modes, and both are pinned:
  ADR-0154's rule is that a dialect feature changes what a conformance mode
  *says*, and a rule with one witness is a rule about one program. }
program foreign_refused_iso(output);
function cbrt(x: real): real; external;
begin
  writeln(cbrt(27.0):0:1)
end.
