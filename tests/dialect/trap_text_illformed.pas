{ AP 6.4.15.2's invariant, enforced where a value enters a text: the bytes
  are well-formed UTF-8 or the program stops (ADR-0191).

  That is 6.4.6's own model for a constrained type and ISO 7185's for a
  subrange (ADR-0018) -- a text's invariant is a constraint on the value like
  any other, and this is what makes every reader past the store entitled to
  assume it. The alternative, refusing every assignment that could fail, was
  what AP 6.4.15.5 said before this was written and would have left a text
  able to hold nothing but literals until a library existed to fill one.

  The bad byte is built at run time rather than written as a literal, so no
  amount of folding can decide it early. }
program trap_text_illformed(output);

var t: utf8(16); s: string(16);

begin
  s := 'ab';
  { 0x80 is a continuation byte with no lead: ill-formed in any position, and
    The Unicode Standard's table 3-7 is where that is said. }
  s[2] := chr(128);
  writeln('about to store two bytes that are not UTF-8');
  t := s;
  writeln('unreachable ', length(t):1)
end.
