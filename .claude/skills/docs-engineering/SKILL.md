---
name: docs-engineering
description: Audit and update all project documentation to stay in sync with the current development status of the Afterschool Pascal compiler.
---

When performing documentation engineering, always follow these steps:

1. **Survey recent changes** — run `git log --oneline -20` and skim the diffs of every commit that could change what the compiler *accepts*, not just the `feat(...)` ones. This surfaces new language features, new builtins, new diagnostics, and changed semantics that documentation may not yet reflect. Note which bootstrap milestone each commit advances.

   **A `fix:` counts.** Now that both standards are complete, a conformance fix is the commonest way the accepted language grows: `4257de8` struck an entire limitation from README and from `doc/roadmap.md` while reading as a bug fix, and this step — which said `feat(...)` — is why nothing flagged that it had no `docs:` commit after it. The test is whether a program that did not compile now does. `refactor:` and `chore:` are the ones that genuinely cannot move the contract; everything else is worth the diff.

2. **Audit** all documentation against the current codebase. Every tracked document is in scope — `git ls-files '*.md'` is the list, and a document absent from the sections below is a gap in *this skill* to be fixed rather than a document to skip. **Each has one audience and one job**, and the commonest defect is not staleness but a paragraph in the wrong file: detail that belongs to a contributor drifting into the user's document, or a feature's mechanism drifting into the file every session loads.

   **The two entry points.**

   - `README.md` — **the user-facing document**, and the only one written for someone who wants to *use* the compiler rather than work on it: what it is, the goal (ADR-0109), building, invoking `pascalc` and `pascalcc`, the accepted-language listings for both standards, a short summary of what backs the answers, pointers to the other documents, and the licence. The **"What the compiler accepts today"** and **"What `--std=extended` adds"** blocks are the contract with a user and the single most stale-prone thing in the repo — every landed feature edits one, and every *unlanded* feature must stay out of both. Keep the "not accepted yet" list accurate too; it is what stops someone filing a bug against an unimplemented feature. No line counts, no internal type names, no commit hashes, no build-tree paths, and no instructions for changing the compiler — those belong in the developer guide.
   - `doc/developer-guide.md` — **the contributor-facing counterpart**: the repository layout table, the second front end, the bootstrap plan and stage 1, how each part is checked, how to add a test and what each sidecar means, and where the decisions are recorded. When a new harness, corpus or sidecar convention lands, it is documented here. Check that its links stay `doc/`-relative — the file lives in `doc/`, so a link copied from README will be wrong by one level and still render.

   **The reference documents**, consulted rather than read.

   - `doc/implementation-defined.md` — what clause 5.1 requires a processor to be accompanied by, and the answer to every entry of both standards' annexes, plus the unreported errors, the extensions and the restrictions. **An entry is answered by compiling a probe, never by reading the source** — that is the rule the document was written under and the one that found two bugs (ADR-0073). Its unreported-errors section is keyed to Annex D and regenerable from `tests/bsi/expected.tsv`; don't quote a count of those entries anywhere, it has moved before.
   - `doc/glossary.md` — the terms this repository uses in a specific sense, each citing the decision that governs it. A feature that invents a word (descriptor, husk, completer) adds it here, or the word has no definition anywhere.
   - `CHANGELOG.md` — Keep a Changelog format, and its subject is **the accepted language, the diagnostics and the command line**, which is what the version number tracks. Released entries are left as they were written even when they name something since retired; only `Unreleased` is edited. `release-engineering` owns the version bump — this skill only keeps `Unreleased` honest.

   **The records**, which are append-mostly.

   - `doc/adr/` — the decision records. **ADRs are immutable once Accepted** (ADR-0001): a decision that stops being right gets a *new* record that supersedes the old one, and the old one's status becomes `Superseded by ADR-00NN`. Never edit the Context or Decision of an accepted record to match new reality — that destroys the reasoning the record exists to preserve. Keep the index table in `doc/adr/README.md` in sync with the files, including status changes. A `Proposed` record that has since been decided must be resolved rather than left drifting; ADR-0012 on strings was the standing example and is Accepted now, so there is currently none.
   - `doc/design-digest.md` — a paragraph per mechanism, condensed from the record that decided it, grouped as the compiler is. A landed feature adds its entry **here, not to `CLAUDE.md`**; every entry cites its ADR, and the ADR is where the alternatives and the cost stay. Check that a new entry names the test that fails when the mechanism is undone — that is what the entry is for.
   - `doc/roadmap.md` — where the compiler is, how it got there, and what is deliberately not being done yet, including what each conformance sweep found. A deferral recorded here rather than fixed is the shape ADR-0075 took, so an item that has since landed must be struck rather than left to imply otherwise.

   **The procedure.**

   - `doc/sop.md` — how a change is classified and what its class must satisfy, and in **§7 the live register of what is currently not checked**. A gate declined in a change is an entry added here in the same commit; §7 going stale is worse than any other staleness in the tree, because it is the document that says what the green bar does *not* mean.
   - `CLAUDE.md` — orientation for a future session: the build/test commands (including the single-test form and the re-run-cmake gotcha), the pipeline and the Sema→CodeGen contract, the gates, what each oracle cannot see, the bootstrap constraints, and the encoded Pascal semantics. It must describe things that take *reading several files* to work out; anything discoverable from one file does not belong. **It is loaded into every session before any work starts**, so it carries what is true of every change and points elsewhere for the mechanism. When a pass gains a new responsibility, its contract bullet must be updated in the same change.

   **The artefact and corpus READMEs**, each the thing a reader consults *before* trusting what it describes.

   - `seed/README.md` — the committed compiler's provenance, its target lock and its refresh policy. Stale here is worse than stale anywhere else: it is what a reader consults before trusting a binary artefact.
   - `verify/README.md` — how to run the proofs, what a rule is, and the three standing rules (the model is maintained with the lowering, a specification states a property and never a computation, a `KNOWN_GAP` that starts holding fails the build). The rule count is quoted in `README.md` and *not* here, which is deliberate — one place to move when it moves.
   - `tests/spec/README.md` — how to add a scenario, the recognised steps, the triage of the clause denominator, and what the suite deliberately is not. A new step kind is documented here or it is invisible.
   - `tests/bsi/README.md` — **BSI's three conditions**, which are a licence obligation rather than a convenience: use is granted and redistribution is not, no representation may suggest a third-party validation, and any statement of results describes the whole suite. No document in this repository may call a BSI run a validation; check that none has started to.

   **The procedures an agent executes**, which are documentation that is *acted on* and so go stale in the same way and more expensively.

   - `.claude/skills/*/SKILL.md` — `change-lifecycle` and the specialists it dispatches to. Each names files, headings and conventions; when one of those moves, the skill that names it is as stale as any prose. `commit-and-push`'s scope list and this file's audit scope are the two that name the most, and this file is in its own scope — a document it does not list is a gap here to be fixed, not a document out of scope.

   **In the source.**

   - **`selfhost/compiler.pas`** — the compiler, and since ADR-0085 the only one. Its header comment says what the file is and why it is one file; each component inside it (lexer, parser, Sema, CodeGen, driver) should be findable from a banner comment. `Usage` carries the flag list, which must match what `ParseArgs` actually accepts.
   - **Item-level comments** — every non-obvious declaration carries a comment describing **intent and the language contract** — the *why*, the ISO clause, the reason a lowering is not the naive one — **not a restatement of the signature**. The bar is "a reader who knows Pascal but not this file can navigate it", not "a comment on every line": trivial accessors and obvious one-liners stay bare. Load-bearing comments that already exist and must not be lost: the `mod` non-negativity note, the `for` limit-then-step note, the variant-record tag-dispatch rationale (which is ADR-0005's C++ constraint outliving the C++), and the width/precision sentinel convention in `runtime/pasrt.c`.
   - `tests/*.pas` — the tests double as language documentation (ADR-0011). A test whose comments explain the rule it pins (`{ -1: a leading sign applies to the whole term }`) is doing documentation work; keep those comments correct when expectations change. **A wrong citation in a test comment is invisible to every oracle here** (ADR-0072), so a clause number in a comment is checked against the clause, not against the fact that the test passes.

3. **Revise and update** any documentation that is stale, incomplete, or inconsistent with the current code. In particular:
   - When a language feature lands, move it from README's "not accepted yet" list into the accepted block, in the same words a user would search for, and add its paragraph to `doc/design-digest.md`.
   - **Route by audience before writing.** A user of the compiler, a contributor to it and a future session need different things, and a paragraph that helps one of them in the wrong file is a defect even when every word of it is true: usage and the accepted language in `README.md`, the repository and its harnesses in `doc/developer-guide.md`, one feature's mechanism in `doc/design-digest.md`, what is true of *every* change in `CLAUDE.md`. When a paragraph would fit two, put it in the more specific one and link from the other rather than saying it twice — a fact stated twice is a fact that will disagree with itself.
   - When a bootstrap milestone or a harness changes, update `doc/developer-guide.md`'s bootstrap plan and its layout table, and say what it unblocks.
   - When a new pass or source file is added, add it to `CLAUDE.md`'s "Where things live" *and* the developer guide's layout table, and give it a header comment.
   - When a decision is made that constrains future work, write the ADR **while the alternatives are still live** — a record written afterwards justifies rather than explains (ADR-0001).
   - When a Pascal semantic is encoded or changed, update `CLAUDE.md`'s "Pascal semantics already encoded" list *and* confirm a test pins it. Documentation of a semantic with no test behind it is a finding.
   - Treat a stale comment that contradicts the code as worse than a missing one — fix or delete it. Adding or correcting a comment must not change code: a doc-only pass leaves `ctest` output identical. There *is* a `clang-format` step again — ADR-0108 brought `src/` back as a reference front end, so a comment touched there is checked like any other line, incrementally (`git clang-format` against the diff, never the tree). The rule it protects is the same either way: a comment fix and a code change do not travel together.

4. **Remove completed items** from any TODO list. If a brief summary of completed work is warranted, add it to `README.md` or the relevant ADR's consequences before deleting the entry.

5. **Commit** documentation changes using the `commit-and-push` skill with scope `doc`, grouped by topic. Don't mix unrelated documentation changes in a single commit. A natural split:
   - **Per-feature README flip**: when a commit lands that changes what the compiler accepts — a `feat:`, but a `fix:` just as much — the immediately-following `docs:` commit moves the feature from "not yet" to "accepted" and nothing else. Keep that cadence — it makes the language's growth greppable from `docs:` alone.
   - **Periodic doc sync**: README, the developer guide, the digest and CLAUDE.md brought back in line with reality after a milestone; these cluster naturally and ship as one commit.
   - **A new ADR is its own commit**, or travels with the change that motivated it. Never bundle an ADR with unrelated doc edits — it should be reviewable on its own.
