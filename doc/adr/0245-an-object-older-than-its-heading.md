# 245. An object older than its heading

Date: 2026-08-29

## Status

Accepted, 2026-08-29.

It closes the sentence `doc/implementation-defined.md` §2.5 has carried since
[ADR-0079](0079-an-interface-is-a-set-of-names.md): *nothing detects a
component whose object is older than its heading*. It also answers half of
[ADR-0244](0244-an-import-that-names-no-file.md)'s closing paragraph, which
said *there is still no compiled interface artefact and no dependency freshness
check* — the second clause is what this record is, and the first stays true and
is why the mechanism is the shape it is.

## Context

§6.11.1 makes a module-heading the interface — the whole of what a client may
depend on — and §6.13 translates the components of a program separately. Put
those together and two translations may read **two different headings** for one
module, and agree about every name in both.

The names are the reason it is silent. A module's exported variables are
reached by linkage name and never by frame index (ADR-0079), its activation
procedures are named from the module and the language (ADR-0119), and a
procedure's name says nothing about its parameters. So a heading that gains a
field, loses a parameter or changes a type resolves against an object built
from the previous one, links, and runs.

It was measured before it was fixed. `store.pas` declaring
`item = record a, b: integer` was translated to an object; the heading then
became `record tag: integer; a, b: integer`; a program compiled against the
*new* heading and linked against the *old* object wrote `a=11 b=22` and read
back:

    a=11 b=0

Exit status 0. No diagnostic from the compiler, from `tools/pascalcc` or from
the linker. That is the worst shape a defect can have here — a wrong answer
where every oracle in this repository agrees, because every one of them
compiles the two halves together.

The standard route out is a compiled interface artefact — Turbo Pascal's
`.TPU`, and every dependency-tracking build system since. This language has
none, deliberately: §6.11.1 puts the interface *in the source*, which is what
ADR-0079 chose and what makes ADR-0244's search a search for `.pas` files. A
second artefact would be a second thing to keep in step.

## Decision

**A digest of the module-heading's tokens is part of the name of that module's
activation procedures.**

    @m.store.afterschool.36e9a637193a2bf7.init

[ADR-0119](0119-the-components-of-one-program-agree-on-the-mode.md) put a
fact the components of one program must agree on into the symbol they already
have to agree on. This is the same move for a second such fact, and it is worth
saying that the mechanism was chosen *because* that record had already proved
it: a program calls this name once for every module it activates (§6.2.3.6), so
a component translated against a different heading cannot reach an executable,
and the check costs the compiler nothing because the **linker** performs it.

Five things were decided rather than assumed.

**Tokens, not text.** A heading differing only in a comment, a separator or its
layout is the same heading, and nobody relinks for a reflow. It also removes a
dependence on where the lexer happened to put a spelling in the string pool:
what is folded in is each token's kind and each character of its spelling. A
digest over text would satisfy the words of AP 6.13.2 and be useless — which is
NOTE 3 of that clause and half of what `stale-component` pins.

**The heading and not the module.** The digest covers exactly `module` to the
heading's own `end`, so a change confined to a module-block — a private
variable renamed, a procedure body rewritten — forces no relink of any client.
That is right rather than merely convenient: §6.11.1 says a client depends on
the heading and on nothing else, and a check that refused more would be
enforcing a rule the language does not have.

**Two 30-bit hashes and not one 64-bit one.** Integer arithmetic here *traps*
on overflow (ADR-0014), so the wrapping multiply every hash function in C is
written with does not exist in this language. The modulus is what keeps the
product inside the type rather than something the compiler has to be told to
ignore: `h * 131` with `h` under 10^9 is 1.3 × 10^11, comfortably inside
`int64`. Two coprime moduli give about 60 bits, which is written as sixteen
hexadecimal digits.

**Looked up by name at emission, not carried on the symbol.** §6.11.1's third
form declares a module as `module M implementation;` with its heading supplied
by another component, so the node being emitted is not the node holding the
heading. Both name the same module, so the emitter asks by name over the module
list — which is also why the answer is keyed on `mdHasHeading` and not on the
digest being nonzero: a hash may legitimately land on zero.

**And the digest is added to the existing tag rather than replacing it.** An
object from a release before ADR-0232 spells a conformance mode where the tag
is; an object from before this record has no digest at all. `tools/pascalcc`
tells the two apart by whether the undefined name has a digest in it, and says
different sentences, because *recompile it* and *recompile it with this
compiler* are different instructions.

## Consequences

`tests/checks/stale_component.sh` is the gate and it is a shell harness for a
reason no sidecar can meet: **no test case can edit its own source between two
compilations.** It is a catalogue of four claims, each failing on its own — a
matching pair links and runs; a heading change without a rebuild does not link,
and the driver names the module; a comment and a reflow in the heading still
link; a change to the module's own block still links.

**Two mutations, each caught by the half it belongs to.** Emitting a constant
digest reproduces the original defect exactly, `a=11 b=0` and all, and the gate
prints what the program printed. Folding a token's *line* into the hash makes
the reflow refuse to link, and the gate says a comment forced a relink. The
second is the one worth having: a check of this kind fails by being too strict
far more easily than by being too loose, and nothing else here would have
noticed.

**AP 6.13.2 is a new clause** and sits beside 6.13.1, whose shape it borrows:
both are requirements about which *objects* may be linked, neither has anything
for a source to state, and both are met at the link. It joins 6.11 and 6.13.1
in `tests/spec/clauses/pending.txt` rather than gaining a scenario, and it is
the sharpest of the three for that purpose — the requirement is precisely that
two objects disagree, and `tests/spec/run.py` compiles one program.
`doc/sop.md` §7 carries the row and now names three clauses instead of two.

**What this does not do.** It does not order a rebuild — it refuses a link, and
the remedy is the user's. It says nothing about a component whose object is
older than its heading in a way the heading does not show: a module whose
*block* changed still links against a client built earlier, correctly, and a
build system is still what decides that the object should be remade. And the
digest is a hash: two different headings colliding in 60 bits would link, which
is the same outcome as before this record for one pair in 10^18.
