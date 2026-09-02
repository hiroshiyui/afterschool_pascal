# 299. Every file variable is bindable

Date: 2026-09-03

## Status

Accepted, 2026-09-03. Closes the decision `doc/roadmap.md` held in two places
— the last entry of "The program that would judge the language" and the first
of its Known-limitations pair — and answers the five findings ADR-0167's third
reader filed under *What is not done*. AP 6.5.1 is the clause.

## Context

ISO/IEC 10206:1991 makes bindability a property a **type-denoter** denotes
(§6.4.1) and a variable takes from its declaration (§6.5.1), a field from its
record-section (§6.4.3.4), a component from its array-type (§6.4.3.5) and an
identified-variable from the pointer's domain-type (§6.4.4). Then §6.7.5.6 and
§6.7.6.8 make `bind`, `unbind` and `binding` of a file that does not possess it
a *dynamic-violation*, and §6.7.3.3 makes a formal variable parameter possess
the bindability of its actual, "determined dynamically" (NOTE 1). ADR-0167's
reader found what that costs and left it recorded rather than fixed; ADR-0170
moved the question from the entire-variable to the variable-access and
returned the field and the component; and the roadmap has carried what was
left since, as four shapes of one question:

1. **A `var f: text` formal** is refused by `bind` inside its body — which is
   §6.7.6.8's own worked example, `procedure bindfile(var f: text)`, and the
   shape `lib/pasfile.pas` met: its four writers were one routine with two
   flags because the helper could not take the file.
2. **A dereference** was answered `bindable` without asking, so `bind(p^, b)`
   compiled for `p: ^text` as well as for `p: ^bindable text`;
   `doc/implementation-defined.md` §6.1 carried it as the one program known
   to be accepted that the standard requires rejected.
3. **A field and a component** were right since ADR-0170 and only in the
   spelling that says the word: `r.plain: text` and `flat[1]` of
   `array of text` were refused.
4. **A non-file** that says the word, `var i: bindable integer`, is refused by
   `bind` — §6.7.5.6's "otherwise" branch presupposes it legal, and what
   binding an integer to an external entity would *mean* was undesigned.

And one thing the entry did not say, found by the two-minute probe this
chapter keeps recommending to itself: **shape 1 already crossed in one
spelling.** `type BText = bindable text; procedure P(var f: BText)` bound
inside its body all along, §6.4.1 letting a type-name hand the word on and the
compiler's own `BindableOf` implementing exactly that. What it costs is the
caller: every actual has to be declared `BText`, name-equivalence (ADR-0017)
admitting no `text`. So the roadmap's *"there is no formal parameter that
accepts one"* was false as written and true in the only spelling a library
could offer, and `lib/pasfile.pas`'s workaround was for the second sentence.

The roadmap named three answers. **Enforce the clause**: carry a bindability
word with every `var` file parameter and check it at run time, the seventh
thing here to travel as two words, and reach the dereference by carrying the
domain's denoter through `ResolvePointer`'s deferred paths. **Make every file
variable bindable**, which dissolves all four shapes at once. **Or leave it.**

## Decision

**Every variable that possesses a file-type is bindable**, whether or not its
type-denoter says so — AP 6.5.1, which reaches an entire-variable, a
component-variable, an identified-variable, a `var` formal and an exported
variable by naming them. `bindable` is still accepted wherever §6.4.1 admits
it and is redundant on a file.

**Bindability of a non-file is what the standard says it is** and nothing
more: `var i: bindable integer` is accepted, 6.9.3.9.1 refuses it as a
control-variable, 6.4.3.4 keeps it out of a variant-denoter, and `bind`,
`unbind` and `binding` refuse it **by design**, the message now saying which
design — *'bind' needs a file variable, found integer: only a file variable is
bindable*. What binding a non-file would mean is deliberately not decided;
AP 6.5.1 says so in its second paragraph so that a processor cannot be read as
having forgotten.

In the compiler this is one arm: `DesignatorBindable` answers true for any
designator whose type is a file-type, before it looks at the declaration.
`bind`, `unbind` and `binding` no longer ask it at all — `IsFile` was already
the first test at each of the three sites, and once a file is bindable it is
the whole test — so `NotBindable`, the one message the three shared, is
**deleted** rather than catalogued: a message no program can reach is a
message `diagnostic-coverage` would otherwise have to be told about
(ADR-0273). The for-statement still asks, and for a non-file the answer is the
declaration's. CodeGen is untouched: `bind` lowered through the designator's
address already, and a `var` formal's slot dereferences to the caller's file.

**Why this answer and not the first.** The clause exists to make a static
property of something the standard admits is dynamic — §6.7.3.3 NOTE 1's word
— and enforcing it costs a second word beside every `var` file parameter at
every call, a run-time check that fails as a dynamic-violation, and a
domain-denoter carried through two deferred paths, all to refuse programs the
standard's own example writes. A dialect with no conformance claim (ADR-0232)
is free to give the answer that removes the check rather than the one that
adds it, and this is the first place that freedom has been used to admit a
program the standard requires rejected rather than to add a construct.

**Why not leave it.** Nothing had asked twice, which is ADR-0116's bar, and
this record is written because the count is wrong: `lib/pasfile.pas` asked,
the language server's `WriteScratch` asked (it holds a `bindable text` for
the same reason), and §6.7.6.8 asked in 1991. Three sites in a tree whose
chapter says a finding recorded and left is a finding wasted.

## Evidence

`tests/dialect/bind_anywhere.pas` writes and reads back through all four
shapes — the formal itself as the designator, `p^` for `p: ^text`, a field
written as a selection and again through a `with`, an element — and through a
`file of integer`, which is there to say the rule is a file-type and not the
text-type. Nothing in it says `bindable`.
`tests/spec/features/dialect_bind_anywhere.feature` cites AP 6.5.1 with the
same five and the two refusals the clause keeps.

**The mutation** puts the standard's refusal back — `DesignatorBindable`'s
file arm made false and `bind` refusing a designator that answers false —
and kills five: `bind_anywhere`, `bind_qualified_plain`, `binding_errors`,
`lib_file` (the rewritten module's `var f: text` helpers) and
`spec-dialect_bind_anywhere`. Everything else stays green — `spec-scopes`
included, its surviving bindability scenario saying the word — which is the
count of places that had been working around the rule.

**Three cases converted honestly.** `tests/extended/binding_errors.pas` lost
eight diagnostics, all §6.7.5.6's dynamic-violation, and keeps the arity, the
argument types, the non-file refusal with its new wording and a substring.
`bind_qualified_bad.pas` became `bind_qualified_plain.pas` with a `.out`,
because the qualified arm still has a claim to pin — a name denoting a file
answers as a file with no base to ask — and the refusal it pinned is gone.
The `scopes.feature` scenario *a field whose type-denoter does not say
bindable may not* is deleted, its positive twin staying under
`@extended:6.7.5.6`.

`lib/pasfile.pas` is the client: `Attach`, `Found` and `Opened` take
`var f: text`, the five readers and four writers each say only which question
they ask, and `Written(path, content, append, terminated)` is gone with the
paragraph that justified it. `binding_errors.pas` and `lib_file.pas` are the
two cases that say the module still does what it did.

## What is not done

**Non-file bindability is not designed.** `var i: bindable integer` is a
declaration the language accepts and 6.9.3.9.1 acts on, and that is the whole
of its meaning here. §6.7.5.6's "otherwise" branch is left as a thing a
processor may define, and this one defines it as a refusal. A feature that
wants it — a variable bound to an environment entry, say — starts from
AP 6.5.1's second paragraph and not from a gap.

**A dereference of a non-file bindable domain answers false.** `p: ^bindable
integer; p^` is not bindable to the for-statement, the only thing that asks,
because the domain's denoter still does not travel through `ResolvePointer`.
Nothing can reach it: a control-variable is an entire-variable. Recorded so
that a second asker knows the answer is an artefact and not a reading.

**`lsp/pasls.pas` keeps its four `bindable text` locals.** They are correct
and now redundant, and the server is not this change's client.

**The `bindable`-in-a-variant row of `doc/sop.md` §7 narrows further.** A
bindable non-file field in a variant arm is still caught only where the word
is written on the arm; a bindable *file* field is caught by §6.4.3.6 before
bindability is asked, files being kept out of variants here (ADR-0070). The
row's second reason is rewritten to say so.

## Consequences

**The containment claim (AP 6.0.1) is untouched and the refusal claim is
narrowed**, and it is worth being exact about which programs move. Every
ISO/IEC 10206:1991 program keeps its meaning: on a file the word denotes
nothing the type does not, and on a non-file it denotes what it did. What is
accepted that the standard requires rejected is exactly `bind`, `unbind` or
`binding` applied to a file variable whose type-denoter does not say
`bindable` — the `var f: text` formal, the plain field and element, and the
`^text` dereference, which was accepted before and is accepted now for a
reason. `doc/implementation-defined.md` §6.1 no longer lists it and §6's
restriction entry says the non-file refusal is a design.

**The first use of ADR-0232's freedom in this direction.** Every dialect
feature before this one added a construct at a position the standard could
not write; this one removes a refusal the standard requires. The test it had
to pass is the one 6.0.1 states — no conforming program changes meaning — and
the thing to carry forward is that it is a *different* test from ADR-0140's,
and needs no spelling, which makes it the fourth feature with none after
ADR-0184, ADR-0240 and ADR-0290.

**A finding recorded with a wrong reason is the shape again.** The roadmap's
sentence about a formal was half false and the probe that showed it took two
minutes — the third time in that chapter, after the `T ! E` entry, the map
entry and the line entry, that a limitation named the language and belonged
to what nobody had tried. The method is unchanged and this record is one more
reason to apply it before writing a row.
