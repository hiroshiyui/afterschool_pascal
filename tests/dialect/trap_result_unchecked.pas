{ The other half of tests/dialect/lib_result.pas: a caller who does not look.

  This is what the shape is *for*. The boolean-and-var-parameter form
  PasText.TryParseInt uses leaves a value behind whether or not it was parsed,
  so the mistake below reads a stale integer and the program carries on with
  it. Here the value and the reason are two arms of one variant, so the read is
  of a variant the tag does not select and ADR-0118 stops the program.

  The trap is not a diagnostic and could not be: nothing is wrong with this
  source, and whether the read is legal depends on what was parsed. That is why
  the sidecar is a .err with a non-zero exit rather than a golden diagnostic. }
program TrapResultUnchecked(output);

import PasError; PasParse;

var r: IntResult;

begin
  r := ParseInt('not a number');
  { the check a caller is supposed to write, and does not }
  writeln('the cause is: ', ErrorText(r.cause));
  writeln('about to read num on a failed result:');
  writeln('val = ', r.val:1)
end.
