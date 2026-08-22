{ ISO/IEC 10206:1991 §6.9.3.9.1, the sentence after the one every processor
  implements: "The control-variable shall possess an ordinal-type and shall be
  nonbindable."

  Two requirements in one sentence, and only the first was asked. The second is
  not decoration: §6.5.1 says "A variable possessing the bindability that is
  bindable shall be totally-undefined while the variable is not bound to an
  external entity", so a for-statement over an unbound one attributes a value
  to a totally-undefined variable -- Annex D's error -- and over a *bound* one
  it writes an external entity once per iteration, which the equivalent program
  fragment §6.9.3.9.2 gives says nothing about. The clause resolves it
  statically instead, and this is that.

  §6.4.3.4 and §6.4.3.5 give a field and an array component the bindability of
  their own type-denoter, so the rule is asked of the variable-access; a
  control-variable is an entire-variable (§6.9.3.9.1 again), so the entire
  variable is what answers here.

  Extended Pascal only: ISO 7185 has no `bindable` in its lexis, so no ISO 7185
  program can possess the bindability this refuses. }
program ForvarBindable(output);
type btext = bindable text;
var i: bindable integer;
    j: integer;
    log: btext;
    c: bindable char;

begin
  { the first requirement, still asked, and unchanged }
  for i := 1 to 3 do j := i;
  for c := 'a' to 'c' do j := j + 1;
  { and a nonbindable one beside it, so the message is about bindability and
    not about for-statements over integers }
  for j := 1 to 3 do writeln(j:1);
  writeln(binding(log).bound)
end.
