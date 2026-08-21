{ Annex B: `?` is the optional type's own character (ADR-0123), and a
  conformance mode refuses it as the lexer always did -- an unrecognised
  character, with no mention of the dialect. That is the right answer and worth
  pinning: ADR-0140's rule is that a dialect feature is spelled where a
  conforming program could not have written it, and a character no conforming
  program may contain is the strongest form of that. There is nothing to name,
  because there is no construct here to have a name under this standard. }
program optional_refused_iso(output);
var x: ?integer;
begin
  x := 1
end.
