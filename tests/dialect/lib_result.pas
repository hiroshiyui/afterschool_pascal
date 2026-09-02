{ ADR-0120: a fallible routine answers one record that carries the value or the
  reason and never both.

  What this pins is that the tag is right without anyone having set it.
  PasParse assigns `r := n` or `r := code` and never `r.ok`, so every `ok` printed
  below was decided by ADR-0118's rule that a write to a variant's field
  activates that variant. Under a Pascal without that rule the same source would
  print whatever the storage held -- which is why ADR-0119 refuses to link
  these modules into a conformance-mode program at all, and why this case is
  under tests/dialect/.

  tests/dialect/trap_result_unchecked.pas is the other half: what happens to a
  caller who does not look. }
program LibResult(output);

import PasError; PasParse;

var r: IntResult;

procedure Show(label_: ParseLine; s: ParseLine);
var got: IntResult;
begin
  got := ParseInt(s);
  write(label_, ': ok=', got.ok);
  { the read is inside the arm the tag selects, which is what makes it legal }
  if got.ok then write(' val=', got.val:1)
            else write(' cause=', ErrorText(got.cause));
  writeln(' [', IntResultText(got), ']')
end;

begin
  Show('plain    ', '42');
  Show('signed   ', '-7');
  Show('spaced   ', '   123   ');
  Show('empty    ', '');
  { Blanks and nothing else. The trim loop reduces this to a string of one
    space, and 6.5.6 has no empty substring -- so before the guard in PasParse
    this line stopped the program rather than reporting a syntax error. Every
    other input here trims to something, which is why the corpus missed it. }
  Show('blanks   ', '   ');
  Show('lone sign', '+');
  Show('trailing ', '12x');
  Show('overflow ', '99999999999');

  { IntOr is the ParseIntOr shape kept: a caller with a default should not have
    to write the case, and does not have to know the read is guarded. }
  writeln('or 0 of ''55''  = ', IntOr(ParseInt('55'), 0):1);
  writeln('or 0 of ''--''  = ', IntOr(ParseInt('--'), 0):1);

  { Failed reads the intent rather than the comparison. }
  r := ParseInt('nope');
  writeln('failed? ', Failed(r.cause));
  r := ParseInt('1');
  writeln('ok, so code is unreadable -- ask the tag instead: ', r.ok)
end.
