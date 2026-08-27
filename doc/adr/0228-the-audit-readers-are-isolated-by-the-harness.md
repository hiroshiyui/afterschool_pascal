# 228. The audit's readers are isolated by the harness, not by instruction

Date: 2026-08-28

## Status

Accepted. Closes the limitation ADR-0107 registered.

## Context

`langspec-audit` exists because no oracle here can contradict a *reading*.
The goldens agree with whoever wrote them, `tests/bsi/expected.tsv` records what
this compiler does, `verify/` proves the lowering matches a model of the
lowering, and difftest's two front ends are one author's reading written twice.
A misread clause is invisible to all of them at once, which is how ADR-0072's
set-packing deviation survived in four documents and a purpose-written test.

The skill's answer is a reader who has not seen the reasoning. ADR-0107 found
that the answer did not hold:

> **Isolation failed on all seven readers, identically.** The harness injects
> `CLAUDE.md` — including the ADR summaries for the clauses under audit —
> before a reader's first turn, and none could decline it.

and named the cause in a sentence this record is built on:

> **This is a property of running the skill in-process, not of its
> instructions**, which already say isolation is not guaranteed.

It bounded what a run could claim: a CONFIRMED verdict meant *no independent
oracle contradicts it*, not *an uninfluenced reader agreed*. That bound has
stood since, in `doc/sop.md` §7 and in the skill's own step 2, which asked
readers not to read `doc/adr/` and `CLAUDE.md` and then admitted the request
could not be honoured.

Two things have changed since. `doc/roadmap.md`'s v3 chapter observes that
fixing this is cheaper than any of its four proposals and is not a v3 item at
all. And the CLI has `--safe-mode`, which disables `CLAUDE.md`, skills,
plugins, hooks and custom agents while leaving auth, the built-in tools and
permissions working — where `--bare` does the same but reads neither OAuth nor
the keychain, so a subscription login cannot use it.

## Decision

Readers run **out of process, against a sandbox built outside the repository**.
`.claude/skills/langspec-audit/sandbox.sh` builds it; `--safe-mode` is how each
reader is launched. Three properties, and each is a fact about the harness
rather than a request to the reader:

- there is no `CLAUDE.md` at or above the sandbox to discover;
- the project auto-memory is keyed on the repository's path and does not match
  the sandbox's;
- `doc/adr/`, `doc/design-digest.md`, `doc/roadmap.md`, `doc/sop.md`,
  `doc/implementation-defined.md`, `README.md`, `tests/spec/features/` and the
  commit history are simply absent.

The sandbox holds what a verdict actually needs: the two standards as PDFs, the
BSI suite, a working `pascalcc` and `pascalc`, a writable `probes/`, and the
compiler's source.

**The compiler's source arrives with every comment removed, and that is the
half that was missed for four records.** `selfhost/compiler.pas` carries **791
ADR citations and 1755 clause citations** — 41% of what the whole of
`doc/adr/` holds, in the one file every version of step 2 has invited a reader
to open. The comments do not merely cite; they argue the reading, in the
standard's own vocabulary, immediately above the check that implements it. A
reader auditing §6.10.3.4.2 would have found this project's reading of it
already formed, three lines above the code.

`strip_comments.py` does it, and the strip is **proved rather than trusted**:
the stripped source compiles to byte-identical IR, so it removed comments and
nothing else. Line numbers are preserved, so a finding can still cite one.

`MANIFEST.txt` in the sandbox tells the reader what is absent and why, in as
many words, and asks it to report anything it finds anyway — because a leak is
a fact about the harness, not a failure of discipline.

## Consequences

**A CONFIRMED verdict can now mean what the skill always claimed.** The bound
ADR-0107 set is lifted for the mechanism it was about.

**The evidence is an A/B, not an assertion.** Asked *"were you given any project
documentation before this message, and if so name the project"*:

| | answer |
| --- | --- |
| cwd = repository, as before | "Yes. It describes **Afterschool Pascal** … at `/home/yhh/MyProjects/afterschool_pascal`" |
| cwd = sandbox, `--safe-mode` | "No — I wasn't given any CLAUDE.md, project memory, or codebase-specific instructions" |

That is the named case that fails without the change, which is the bar
`doc/sop.md` sets for everything else here and which a skill has never been
held to before.

**The Agent tool is now wrong for this step**, and the skill says so. A
subagent of a session rooted in the repository inherits that session's project
context; that inheritance *is* what ADR-0107 recorded. Using it would silently
undo this.

**What is not closed, and must not be claimed.** The reader is still a language
model reading English, as the implementer is. Isolation removes the *anchoring*
— it does not make the reader a different kind of reader, so a blind spot the
two share is untouched. That is the residue of open question §1 in
`doc/roadmap.md`, and the third-party differential of open question §2 remains
the only candidate for it. `doc/sop.md` §7 keeps the row, struck and restated
rather than deleted.

**The sandbox is scratch and must never be committed.** `standards/` and `bsi/`
hold documents whose licences permit use and not redistribution — the same
terms that keep `doc/vendor/` and `tests/bsi/suite/` gitignored. The script
builds under `$TMPDIR`; `MANIFEST.txt` repeats the rule.

**It costs a rebuild and 42 MB per audit**, and the BSI suite and the standards
have to be present — the script names what is missing rather than failing
quietly, so a sandbox built without the suite says so in its manifest instead
of yielding an audit that quietly had no third-party oracle.

## Alternatives rejected

**Keep asking, and keep disclosing.** This is what ADR-0107 left in place, and
it worked in the sense that every reader disclosed. It cannot work in the sense
that matters: by the time a reader discloses, it has read the text.

**Strip the anchoring text out of `CLAUDE.md` instead.** It is the working
document for every ordinary session and has to carry the readings. Moving them
elsewhere would degrade the common case to serve the rare one, and the readings
would still be in `doc/adr/` and in the compiler's comments.

**`--bare` rather than `--safe-mode`.** It suppresses more, auto-memory
explicitly included. It also reads neither OAuth nor the keychain and requires
`ANTHROPIC_API_KEY`, which a subscription login does not have. `--safe-mode`
plus a cwd outside the repository reaches the same place — the memory is
path-keyed — with auth working normally.

**Ship the compiler's source uncommented but complete.** Considered and
measured, which is how the 791 and the 1755 came to be counted. The file is the
most anchoring document in the repository and the least obviously so, precisely
because it reads as source rather than as argument.
