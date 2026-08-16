---
name: docs-engineering
description: Audit and update all project documentation to stay in sync with the current development status of the Afterschool Pascal compiler.
---

When performing documentation engineering, always follow these steps:

1. **Survey recent changes** — run `git log --oneline -20` and skim the diffs of recent `feat(...)` commits. This surfaces new language features, new builtins, new diagnostics, and changed semantics that documentation may not yet reflect. Note which bootstrap milestone each commit advances.

2. **Audit** all documentation against the current codebase. The review scope must include — without exception:

   - `README.md` — **a user-facing document**: what the compiler is, the self-hosting goal, build and usage instructions, the accepted-language list, and the bootstrap plan. The **"What the compiler accepts today"** block is the contract with a user and is the single most stale-prone thing in the repo — every landed feature edits it, and every *unlanded* feature must stay out of it. Keep the "not accepted yet" list accurate too; it is what stops someone filing a bug against an unimplemented feature. No line counts, no internal type names, no commit hashes.

   - `CLAUDE.md` — orientation for a future session: the build/test commands (including the single-test form and the re-run-cmake gotcha), the pipeline and the Sema→CodeGen contract, the gates, what each oracle cannot see, the bootstrap constraints, and the encoded Pascal semantics. It must describe things that take *reading several files* to work out. Anything discoverable from one file does not belong here. **It is loaded into every session before any work starts**, so it carries what is true of every change and points elsewhere for the mechanism: a paragraph that belongs to one feature belongs in `doc/design-digest.md`. When a pass gains a new responsibility, its contract bullet must be updated in the same change.

   - `doc/design-digest.md` — a paragraph per mechanism, condensed from the record that decided it, grouped as the compiler is. A landed feature adds its entry here, not to `CLAUDE.md`; every entry cites its ADR, and the ADR is where the alternatives and the cost stay. Check that a new entry names the test that fails when the mechanism is undone — that is what the entry is for.

   - `doc/adr/` — the decision records. **ADRs are immutable once Accepted** (ADR-0001): a decision that stops being right gets a *new* record that supersedes the old one, and the old one's status becomes `Superseded by ADR-00NN`. Never edit the Context or Decision of an accepted record to match new reality — that destroys the reasoning the record exists to preserve. Keep the index table in `doc/adr/README.md` in sync with the files, including status changes. A `Proposed` record that has since been decided (ADR-0012 on strings is the live one) must be resolved rather than left drifting.

   - **`selfhost/compiler.pas`** — the compiler, and since ADR-0085 the only one. Its header comment says what the file is and why it is one file; each component inside it (lexer, parser, Sema, CodeGen, driver) should be findable from a banner comment. `Usage` carries the flag list, which must match what `ParseArgs` actually accepts.
   - **`seed/README.md`** — the committed compiler's provenance, its target lock and its refresh policy. Stale here is worse than stale anywhere else: it is what a reader consults before trusting a binary artefact.

   - **Item-level comments** — every non-obvious declaration carries a comment describing **intent and the language contract** — the *why*, the ISO clause, the reason a lowering is not the naive one — **not a restatement of the signature**. The bar is "a reader who knows Pascal but not this file can navigate it", not "a comment on every line": trivial accessors and obvious one-liners stay bare. Load-bearing comments that already exist and must not be lost: the `mod` non-negativity note, the `for` limit-then-step note, the variant-record tag-dispatch rationale (which is ADR-0005's C++ constraint outliving the C++), and the width/precision sentinel convention in `runtime/pasrt.c`.

   - `tests/*.pas` — the tests double as language documentation (ADR-0011). A test whose comments explain the rule it pins (`{ -1: a leading sign applies to the whole term }`) is doing documentation work; keep those comments correct when expectations change.

3. **Revise and update** any documentation that is stale, incomplete, or inconsistent with the current code. In particular:
   - When a language feature lands, move it from README's "not accepted yet" list into the accepted block, in the same words a user would search for.
   - When a bootstrap milestone completes, update the dependency list in README's bootstrap plan and say what it unblocks.
   - When a new pass or source file is added, add it to `CLAUDE.md`'s "Where things live" and give it a header comment.
   - When a decision is made that constrains future work, write the ADR **while the alternatives are still live** — a record written afterwards justifies rather than explains (ADR-0001).
   - When a Pascal semantic is encoded or changed, update `CLAUDE.md`'s "Pascal semantics already encoded" list *and* confirm a test pins it. Documentation of a semantic with no test behind it is a finding.
   - Treat a stale comment that contradicts the code as worse than a missing one — fix or delete it. Adding or correcting a comment must not change code: a doc-only pass leaves `ctest` output identical. There is no `clang-format` step any more — there is no C++ — but the rule it protected still holds: a comment fix and a code change do not travel together.

4. **Remove completed items** from any TODO list. If a brief summary of completed work is warranted, add it to `README.md` or the relevant ADR's consequences before deleting the entry.

5. **Commit** documentation changes using the `commit-and-push` skill with scope `doc`, grouped by topic. Don't mix unrelated documentation changes in a single commit. A natural split:
   - **Per-feature README flip**: when a feature commit lands, the immediately-following `docs:` commit moves the feature from "not yet" to "accepted" and nothing else. Keep that cadence — it makes the language's growth greppable from `docs:` alone.
   - **Periodic doc sync**: README + CLAUDE.md brought back in line with reality after a milestone; these cluster naturally and ship as one commit.
   - **A new ADR is its own commit**, or travels with the change that motivated it. Never bundle an ADR with unrelated doc edits — it should be reviewable on its own.
