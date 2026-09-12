# ADR-0413: One implementation per program, and a translation is what enforces it

## Status

Accepted.

## Context

ADR-0410 wrote AP 6.7.10's uniqueness requirement as

> For a given type there shall be at most one inherent-implementation in a
> program-component.

and the same sentence for a trait and a type. That was written when an
implementation was a fact about one translation: ADR-0341 had deferred the
module-side form, so the only implementations a program had were the ones it
wrote itself, and *in a program-component* and *in a program* were the same
sentence.

ADR-0411 changed that and the requirement was not revisited. An implementation
in a module-block now reaches the clients of its module (AP 6.7.10.5), so two
modules may each implement one type while each conforms to the clause as
written. Nothing in the document then says what a program importing both
means — and AP 6.7.10.2 has no answer to give, because it selects from the
receiver's *type* and would find two candidates with nothing in the text to
choose between them.

This was found by measuring the rest of `lib/` for the rewrite ADR-0412's
feature exists for. `lib/dialect/pashttps.pas` is the live case: its three
routines each take a `PasTls` `Connection` first, so it is exactly the module
that would want `impl Connection` — and `PasTls` already has one.

**Everything below was probed rather than read** (`doc/sop.md` §4b). Three
modules: one declaring a type, two importing it and each implementing it.

- Either implementer **alone** compiles, and so does a program importing it —
  and the implementation is reachable from that client, which never asked for
  it. **Ownership is not what the processor enforces.** The plan for this work
  assumed a module may not implement another module's type; it may, and the
  library rule below is a convention rather than a refusal.
- A program importing both is refused.
- A component is refused when the other implementer is merely **handed to the
  same translation** — `--import` — although it imports neither it nor
  anything that reaches it. The diagnostic lands on the second component:
  `'shape' already has an 'impl' of its own`.

The third is the one that does not follow from anything written down.

## Decision

**AP 6.7.10's two uniqueness requirements are stated of a program**, not of a
program-component, and NOTE 12b says why: a rule about which routine `x.M`
denotes has to be a rule about the whole program, because 6.7.10.5 carries an
implementation to every client of its module. The consequence for a library is
a sentence: **a module must not give an implementation to a type it does not
declare**, unless it is content to be the only module that ever does.

**The processor's rule stays stricter than the clause, and Annex E records
the gap rather than the clause being written down to it.** What it enforces is
*at most one visible in this translation*, where visible means handed to the
translation. It is a safe over-approximation: it can refuse a translation no
program could have distinguished, and it can never admit an ambiguity.

Refusing on **reachability** instead — did this unit's imports, transitively,
already implement this type — is the version that would agree with the clause
exactly, and it needs a fact this compilation does not have. A module-heading
carries no summary of what its imports implement, which is ADR-0317's sentence
one clause over; computing it would mean reading every component's block, and
a `--import` gives this compilation a *heading*. The honest position is that
the strict rule costs a refusal that is never wrong about a program, and that
the clause and the processor are now known to differ in a stated way instead
of by accident.

**An inherent implementation for a type produced from a schema is refused**,
which is the one change to what the compiler accepts. 6.4.7 interns a
production by its schema and its tuple, so `string(255)` written in one
component *is* `string(255)` written in every other and in every client:
`PasFile.FilePath`, `PasStrVec.StrItem` and `PasJson.JsonName` are one type.
Routines of its own would therefore be routines of all of them, held by
whichever component was translated first, and the rule above would refuse the
second — a program-wide claim staked through a type no component declares. AP
6.7.10 already refused a schema and a subrange and said nothing about a
production; it says it now, and the message is `a type produced from schema
'string' is the same type wherever it is written, so it cannot carry an
implementation of its own`.

**The trait form is deliberately not restricted**, and the difference is how a
routine is reached rather than what the type is. A trait implementation is
selected only where a trait bound asks for one (AP 6.7.9), so the component
writing `impl Sortable for Name` is the one that named both the trait and the
type, and making a string-type of one's own sortable or usable as a map key is
what the facility is for. The first attempt refused both forms and broke
`traits`, `lib_sortx` and `lib_container` — which is the mutation for the
narrowing: widen it again and those three fail while `methods_errors` passes.

This is what decided `lib/pasfile.pas`, which was the third-ranked candidate of
the batch that motivated this record: nine of its fourteen exported names take
a `FilePath` first. It stays as it is, and so do `PasProcess`'s `Run`,
`Capture` and `CaptureLines`, which take a `CommandLine`.

**The harness gained the ability to state this at all.** Until now
`tests/run_test.py` bailed with a message of its own when one of §6.13's
components failed to translate, and compared nothing — so the one refusal that
can *only* happen while translating a component had no golden anywhere. It now
compares the component's diagnostics against the case's `.err` when there is
one, exactly as it already did for the program's, and still fails loudly when
there is not. `tests/dialect/impl_two_modules.pas` is the case.

## Consequences

- `doc/afterschool-pascal-spec.md` 6.7.10 says *in a program*, with NOTE 12b;
  Annex E.15 records what the processor does instead and why it is not closed;
  Annex F gains the row.
- `tests/dialect/impl_two_modules.pas` and its three components pin the
  refusal, its position and its wording. Reverting the harness change makes
  that case fail with `component components/shapeedge.pas did not translate`,
  which is the mutation: the case cannot be written without it.
- A library rewriting its routines as methods now has a rule to check against,
  and one module in this tree is decided by it: `PasHttps` keeps `HttpsSend`,
  `HttpsReceive` and `HttpsExchange` as exported names. ADR-0298's prefix
  argument is what covers it, and its comment in that source was already right.
- `selfhost/apfront.pas` refuses an inherent implementation for a schema
  production, beside the subrange refusal it sits next to.
  `tests/dialect/methods_errors.pas` holds it, and the golden was regenerated:
  the only new line is that refusal, the rest moved by the lines the case
  gained. Three mutations, three different sets of cases — remove the refusal
  and `methods_errors` alone fails; widen it to the trait form and `traits`,
  `lib_sortx` and `lib_container` fail while `methods_errors` passes; remove
  the duplicate-implementation refusal and `impl_two_modules` and
  `methods_errors` fail together, which is the same rule at both scopes.
- The rest is a defect in the **document** (AP 5.5 b)), found by probing what
  the document permitted, and there the processor was already refusing what no
  program could mean.

## Alternatives rejected

**Write the clause down to the processor — *at most one visible in a
translation*.** It would make the document agree with the compiler by
describing it, which is the one thing a specification here may not do
(ADR-0135): the rule a program has to satisfy would then be stated in terms of
how a translation happens to be invoked, and `--import`ing an unrelated
component would change what a program means.

**Leave it at *program-component* and say a program importing two is an
error.** That is where it already was, and it is what let the question go
unasked: each component conforms, the program is refused, and no clause
predicts it.

**Make the compiler refuse on reachability.** It is the version that agrees
with the amended clause exactly, and the fact it needs — what each imported
component's block implements — is not in a module-heading. It would be a
second summary beside the digest ADR-0245 already keeps, and the cost of
getting it wrong is admitting the ambiguity rather than refusing a translation
that was fine. Worth doing if the strict rule ever refuses something real;
Annex E.15 is where that would be noticed.

**Give a program a way to choose — a qualified method call.** It would be a
new spelling for a situation the library convention already forbids, and
§6.11.2's `qualified` import exists for names, not for implementations. No
program here has asked for it.
