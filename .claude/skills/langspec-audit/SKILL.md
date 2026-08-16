---
name: langspec-audit
description: Audit this compiler's readings of ISO 7185 / ISO/IEC 10206:1991 by having independent readers try to prove them wrong, from the standards text and compiled probes.
---

This is not a code review and not a test run. It audits **interpretations** — the
sentences of the standard that a conformance decision turned on — by asking
readers who have not seen the reasoning to reach their own verdict and disagree.

**Why it has to exist here.** No oracle here can contradict a *reading*. What
they all have is one source. `difftest.sh` is back since ADR-0108 and green
over every file, but its two implementations are written by one author from one
reading — which is how ADR-0073's comment-delimiter rule came to be wrong in
*both*, with the oracle comparing them happily. The goldens were written from this
compiler's output, so they agree with whoever wrote them. `tests/bsi/expected.tsv`
is a catalogue of what this compiler does, edited by the person who changed it.
`verify/` proves the lowering matches a model of the lowering. None of them can
say "you read §6.4.3.3 wrong" — and a misreading is invisible to every one of
them at once. ADR-0072's set-packing deviation survived in four documents and a
purpose-written test for exactly that reason.

**`tests/spec/` does not close that gap and this skill is not redundant now that
it exists.** ADR-0105 says so in its own Decision: a scenario is written by the
same reader who might misread the clause, so the suite makes a reading
*findable* — attached to the clause it claims to be about — without making it
*checked*. That is a real improvement and it is the wrong one to mistake for
this. What the suite changes is the audit's economics: there is now a written,
clause-tagged claim to attack instead of behaviour to infer, which makes a
reader's verdict sharper and its target easier to choose.

Run this after a batch of conformance work, before a release, or whenever a check
was added whose clause admits more than one reading.

When performing a language-specification audit, always follow these steps:

1. **Choose what to audit, worst first.** Not every decision — the ones carrying
   judgement. Rank by these signals, which are ordered by how often they have
   actually indicated a misreading in this repository:
   - **The check broke programs in this tree and the programs were edited.**
     The strongest signal there is. It is the correct response when the corpus
     was wrong, and it is also exactly what defending a misreading looks like.
     ADR-0096 changed three test programs; the reading survived audit, but that
     was not knowable in advance.
   - A **deviation was retired** on the strength of re-reading a clause.
   - The clause has a **NOTE, an exception, or a cross-reference** that the
     implementation leans on.
   - **Two readings were available** and one was picked — especially where the
     other is what a reasonable implementer would assume.
   - The rule **refuses something common**. Over-strictness is the direction a
     user cannot work around.

   **`tests/spec/` answers "which clauses" from both directions, and they are
   not the same question.** `python3 tests/spec/run.py --coverage` lists the
   clauses a scenario cites; `tests/spec/clauses/pending.txt` lists the testable
   ones no scenario cites yet.
   - **A cited clause is the easiest reading here to attack**, and the best
     value for a reader's time: the claim is written down, phrased as the
     requirement, and attached to the clause it is about. A scenario that
     survives an adversarial reading is worth much more than one that has only
     ever been run.
   - **An uncited clause the compiler implements is where an unexamined reading
     hides.** Nothing has ever stated what the compiler thinks that clause
     means, so there is no claim to check — which is not the same as the claim
     being right. Prefer these when the audit is broad rather than following a
     specific change.

2. **Fan out to independent readers, one group of clauses each.** Use the Agent
   tool; three to five clauses per reader is the right size. Each must be told:
   - **Do not read `doc/adr/`, `CLAUDE.md`, or any commit message.** They carry
     the implementer's reasoning and will anchor the verdict.
   - **Do not read `tests/spec/features/` for a clause under audit**, and this
     one is easy to get wrong because the suite looks like evidence. A scenario
     is the implementer's reading written in the standard's own vocabulary,
     which makes it the most anchoring text in the repository — a reader who
     sees "the bounds are checked only if the statement is executed" before
     opening §6.8.3.9 will find that sentence in the clause whether or not it is
     there. Cite it *after* reaching a verdict, never before. Reading scenarios
     for clauses **not** under audit is fine and is how the dialect is learnt.
   - Read only the standards, the compiler's *behaviour*, and
     `selfhost/compiler.pas` where it is necessary to see what a check does.
   - **Be adversarial**: assume the implementer misread the clause and try to
     prove it. Hunt for programs **wrongly refused** as the primary target.
   - Describe the behaviour to audit **without the reasoning behind it** — say
     what the compiler accepts and refuses, never why.

   **State plainly that the isolation is not guaranteed and require disclosure.**
   The harness injects `CLAUDE.md` into a subagent's context automatically; one
   reader in the first run of this skill was exposed before it could decline, and
   said so. Ask every reader to report whether it saw project documentation and
   what it did about it. An audit's independence is a property of the harness,
   not of the instruction.

3. **Set the evidence bar in the prompt, because it is what separates this from
   guessing.** Require:
   - **The clause quoted verbatim** for every claim. `doc/vendor/iso7185.pdf` and
     `doc/vendor/iso10206.pdf` are readable — `pdftotext -layout` works. **Never
     commit `doc/vendor/`.**
   - **"I could not confirm" is an acceptable answer** and a paraphrase from
     memory is not. A confident wrong quotation is the worst possible output of
     this skill, because it will be believed.
   - **Compiled probes, not reasoning about what the compiler would do.** Write
     them to the scratchpad, compile with `tools/pascalcc`, record accept/reject.
     Probes must not be written into the repository.
   - **Watch the extraction.** `pdftotext` drops `fi`/`fl` ligatures, so `fixed`
     comes out `xed` and `file` comes out `le`; it renders `^` as `"`. A reader
     quoting mangled text should say so and restore it in brackets.

4. **Point every reader at the BSI suite, which is the one oracle nobody here
   wrote** (ADR-0086; `tests/bsi/suite/`, gitignored, fetched by
   `tests/bsi/fetch.sh`). Three uses, in descending strength:
   - **Recompile every CONFORM program.** One that this compiler refuses is the
     strongest available evidence of over-strictness. Know the expected
     exceptions first, from `tests/bsi/expected.tsv`, so a known deliberate
     refusal is not reported as a discovery.
   - **Read the DEVIANCE header comments.** BSI states which clause each program
     violates, in its own words, and sometimes the history: DEV073 records *"Test
     reclassified from CONFORMANCE to DEVIANCE due to change in DP7185"*, which
     settled the hardest question in the first run of this skill. Nothing else
     available here can date a rule's change.
   - Check that the programs for the audited clause are catalogued as the
     category expects.

5. **Audit the clause triage, because it is a reading and ADR-0106 says nothing
   here can check it.** `tests/spec/clauses/triage.tsv` classifies all 292
   headings `testable`, `structural` or `not-implemented`, and
   `spec-clause-traceability` enforces the classification without ever asking
   whether it is right. The dangerous direction is one-way:
   - **A requirement filed as `structural` disappears.** It leaves the
     denominator, so no scenario is ever asked for and the pending list — the
     work queue — never names it. A wrongly `testable` clause only ever wastes
     someone's time.
   - So give one reader the `structural` rows for the clauses in scope and ask
     the single question: **does this clause require anything of a processor or
     a program?** A container, a definition of a term, a compliance statement
     and one of the standards' own examples are the four legitimate answers;
     anything else is a finding.
   - `not-implemented` carries a second claim — that the processor deliberately
     lacks the feature. Check it against `doc/implementation-defined.md` rather
     than against the standard, since it is a fact about this compiler.

6. **Require a verdict per behaviour, in these words**, so the report can be
   acted on without re-reading it:
   - **CONFIRMED** — with the clause text that settles it.
   - **OVER-STRICT** — with a legal program refused, and the clause making it legal.
   - **UNDER-STRICT** — with an illegal program accepted, and the clause forbidding it.
   - **UNSETTLED** — the clause genuinely admits both readings; say what turns on
     it and which a conforming processor is likelier to take.

   Ask for findings **ranked by how likely they are to break a real program**.

7. **Adjudicate — do not merge a verdict on the strength of it being returned.**
   For every finding, reproduce the probe yourself before acting. A reader may be
   wrong in either direction, and both have happened here: one claimed a mechanism
   was load-bearing for self-hosting when mutating it away left the suite green,
   and one claimed a construct appeared nowhere in the tree when a test existed
   for precisely it. **Re-read the quoted clause yourself when a verdict would
   change the compiler.**

   Two clause-level questions decide many cases and are worth asking directly:
   - **Is the violation an *error*?** ISO 7185 §3.1 makes an error something a
     processor may leave undetected; Annex D enumerates them. A requirement *not*
     in Annex D falls under §5.1 e), which obliges the processor to report it and
     refuse execution. So "the standard says shall" and "the compiler must reject
     it" are different claims, and Annex D is what joins them.
   - **Does the clause have more sentences than were implemented?** §6.7.3.3 has
     three and this compiler had two. Read the whole paragraph, not the sentence
     that motivated the change.

8. **Fix the under-strict findings, and hold them to the ordinary bar** —
   `commit-and-push`'s rules apply. Each needs a test that fails without the fix
   and a **mutation that a named test kills**; a green suite after a fix proves
   nothing on its own. Where the fix is Extended-Pascal-only, say which standard
   in the test's own comment.

   **A conformance fix takes a scenario as well as a `tests/*.pas` pair**, and
   they are not redundant: the pair pins the compiler's behaviour, the scenario
   states the requirement the audit settled and files it under the clause. The
   audit is what makes the scenario worth writing — its reading has been
   attacked, which is more than can be said for one written alongside the
   feature. Regenerate `pending.txt` (`run.py --write-pending`) and say in the
   commit message which clause gained a scenario.

9. **Record the confirmations, not only the fixes.** This is the step most likely
   to be skipped and the one that pays. Write an ADR that says which readings were
   audited, what evidence settled each, and what remains unsettled. A reading that
   has survived an adversarial check is a different thing from one that has merely
   not been challenged, and the next reader cannot tell them apart unless it is
   written down. Name the clause and the evidence, not the verdict alone.

   **A CONFIRMED reading earns a scenario too, and this is the half most easily
   dropped** — nothing broke, so nothing demands the work. An ADR records that
   the audit happened; a scenario is what a later reader finds when holding the
   clause, which is the whole point of `tests/spec/` (ADR-0105). Write it for the
   requirement the audit examined, not for the behaviour that was already
   passing.

   An **UNSETTLED** verdict gets no scenario. The suite states what the standard
   requires, and a scenario asserting one of two defensible readings would
   launder a coin-flip into a citation. It goes in the ADR and in `doc/sop.md`
   §7 instead.

10. **Report findings** grouped as **Confirmed**, **Over-strict**, **Under-strict**,
   **Unsettled**, and **Not fixed**. For each: the clause, the quoted sentence, the
   program that demonstrates it, and — for anything left alone — why. Say plainly
   where a correct rule will reject previously-working code: §6.8.3.9's threat
   rule outlaws a global loop counter that any procedure in the block assigns, and
   that belongs in release notes rather than in a compiler change.
