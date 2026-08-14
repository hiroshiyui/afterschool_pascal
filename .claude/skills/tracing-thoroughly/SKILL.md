---
name: tracing-thoroughly
description: A disciplined workflow for tracing hard / stubborn compiler bugs in Afterschool Pascal without tunnel-visioning — classify which pass owns the failure, shrink to a minimal repro, write the hypothesis with explicit falsification, bisect by optimisation level and by pass, read the IR the compiler actually emitted, ALWAYS fan out to multiple parallel agents with competing hypotheses, and run a self-check tripwire when probes stop narrowing. Use it for miscompilations, wrong output, crashes on valid input, and any bug where the first few probes haven't eliminated a cause.
---

**★ ALWAYS FAN OUT — spawn multiple parallel agents by default.** This skill mandates multi-agent tracing: whenever you do real investigation (step 4's pass-ownership sweep, step 6's divergence hunt, and always at step 7's stuck check), spawn **several parallel agents with *competing* hypotheses** via the `Agent` tool (e.g. one audits the emitted IR against the AST, one bisects the optimisation level, one diffs against a reference compiler). Do **not** wait to be asked and do **not** ride a single thread — parallel competing agents are the anti-tunnel-vision default here.

**★ Also surface the reasoning-effort lever (it is NOT automatic).** Up front, remind the user to **adjust the reasoning effort** to the top tier for a hard bug (`/effort`, or `/config` → reasoning effort). Debugging is reasoning-bound, and a compiler miscompilation is the reasoning-heaviest bug class in this repo. Say this *before* deep tracing so the work isn't run under-resourced.

Trace hard bugs in this order. The most important step is the **stuck check (step 7)** — invoke it the moment you've spent a few probes without *eliminating* a hypothesis, or the moment you reach for a "last resort". **Every probe must be observer-only**: reading IR, timing, and diffing change nothing. A "probe" that edits codegen to see what happens is a change, not an observation — make it a hypothesis test with a predicted outcome, or don't make it.

1. **Classify before explaining — which pass *owns* the bug?** The symptom appears at the end of a pipeline, and **the pass where it is visible is rarely the pass that is wrong**. Wrong program output can come from any of five places, and one command separates them:

   ```sh
   tools/pascalcc -O0 --emit-llvm bug.pas -o /dev/stdout
   ```

   - **IR looks wrong and matches the source's meaning being misread** → front end. Check the AST shape first: a precedence bug (`-7 mod 3`) is a *parser* bug that looks exactly like a codegen bug in the output.
   - **IR is well-formed but has the wrong types or a missing conversion** → Sema. An `i32` where a `double` belongs, a missing `SIToFP`, an unresolved symbol.
   - **IR is wrong in shape** — wrong comparison predicate, missing branch, φ from the wrong block → CodeGen.
   - **IR is right and the program still misbehaves** → the runtime (`runtime/pasrt.c`) or the linking. Check the formatting rules before the compiler.
   - **`-O0` is correct and `-O2` is wrong** → this is the important one; see step 5. It almost always means we emitted IR whose *stated* meaning is stronger than what we meant.

2. **Make it deterministic and SMALL first.** Compilers are fully deterministic given their input, so an "intermittent" failure is a *different input* (or uninitialised memory in the compiler — go straight to the ASan build from the `security-audit` skill). Before tracing, shrink:
   - Reduce the `.pas` file by hand: delete declarations and statements, halving each time, until every remaining line is required to reproduce. A 5-line repro is worth an hour of tracing a 200-line one.
   - Keep the reduced file — it becomes the regression test in step 8.
   - If the bug is in the IR rather than the source, `llvm-reduce` (`/usr/lib/llvm-21/bin/llvm-reduce`) shrinks a `.ll` against an interestingness script.
   - **Don't trace until you have a fixed, minimal foothold.**

3. **Write the hypothesis down — with falsification and a rival.** Before probing, state: (a) the current hypothesis, (b) the single observation that would **falsify** it, (c) at least one **competing** hypothesis in a *different pass* than the first. This is the anti-tunnel-vision anchor — if you can't name what would disprove your hypothesis, you'll confirm it forever. In this codebase the productive rival is almost always one pass earlier than where you are looking.

4. **Win by COMPLETENESS, and diff a reference compiler EARLY.**
   - **Read the whole emitted function**, not the instruction you suspect. A miscompilation is often correct-looking code plus one missing branch — the thing that is *absent* never draws the eye, so enumerate: does every block have exactly one terminator, does every φ list every predecessor, is the insert point where the previous helper left it, was a conversion dropped.
   - **Check the AST against the source before blaming codegen.** Precedence and associativity bugs masquerade as lowering bugs. If the language rule is in doubt, the ISO 7185 grammar is the authority, not intuition.
   - **Run a reference compiler EARLY, not as a last resort.** Free Pascal in ISO mode is the behavioral oracle for "what should this program print":
     ```sh
     fpc -Miso -o/tmp/ref bug.pas && /tmp/ref     # vs our output
     ```
     `fpc` is **not currently installed** — `apt install fp-compiler` to enable this, and it is worth doing before a hard trace rather than during one. Where the oracle and the standard disagree, the standard wins and the oracle is a hint; where our output and *both* disagree, the bug is ours and the trace has a target.
   - Cross-check the IR itself with `clang`: write the equivalent C, compile it with `clang -O0 -S -emit-llvm`, and diff the shapes. It answers "what should this lower to" without guessing.

5. **Bisect the optimisation level — then the pass.** When `-O0` is right and `-O2` is wrong, the optimiser is almost never the bug. It means our IR *claims* something we did not intend, and a pass believed it. The usual suspects here are the `nsw` flags on arithmetic, `unreachable` after a call that can in fact return, and a load from an `alloca` that was never stored.

   Narrow it mechanically:
   ```sh
   tools/pascalcc -O0 --emit-llvm bug.pas -o /tmp/bug.ll
   /usr/lib/llvm-21/bin/opt -O2 -print-changed /tmp/bug.ll -S -o /dev/null | less   # first pass that breaks it
   /usr/lib/llvm-21/bin/lli /tmp/bug.ll                                             # run the IR directly
   ```
   `-print-changed` shows the IR after each pass that modified it, so the transition from correct to incorrect is visible, and the pass that made it names the assumption we violated. Then fix *the assumption in codegen*, never by weakening the pipeline.

6. **Trace TO the divergence, then PIVOT to audit.** The instant a trace shows **wrong output from correct-looking code**, stop chasing the symptom downstream and audit the language feature at that point. The Pascal program under test is not wrong: if it is valid ISO 7185 and we produce the wrong answer, that is our bug, full stop — resist the pull to argue the program is relying on something unspecified until you have checked the standard and can cite the clause. **Reuse a construct's signature failure mode**: once a feature reveals one class of bug (a sign-extension error, a block-terminator error), check that class *first* on the next failure in the same area.

7. **★ THE STUCK CHECK — run it, don't skip it.** After **~3–4 probes on one hypothesis that haven't *eliminated* anything**, or the moment you reach for a "last resort" (ask the user, rewrite the pass, give up), STOP and write:
   - the current hypothesis and exactly what you have **ruled out**, with evidence;
   - whether the data is **narrowing** the cause or just accumulating (re-reading the same IR with fresh eyes = tunnel vision);
   - one **fresh competing** hypothesis you have not tried, in a different pass;
   - then **FAN OUT (mandatory, not a choice)** — spawn parallel agents with *competing* hypotheses (one audits the full emitted function, one bisects with `opt -print-changed`, one diffs the oracle, one re-derives the expected behaviour from the standard) rather than riding a single thread.

   Tells you are looping: gathering more IR without options shrinking; explaining away an output that doesn't fit; deciding the test expectation must be wrong (sometimes true — `-7 mod 3` was exactly that — but it is the *conclusion* of a trace, never its opening move).

8. **Fix the ROOT, anchored in a language invariant — and add a regression.** Target the invariant that covers the whole *class*, not the one statement in the repro. Name it in the fix's comment: a sign binds to the whole term; `mod` is non-negative; `char` compares unsigned; the `for` limit is evaluated once; Sema leaves no null types (ADR-0008); every basic block gets exactly one terminator. Then:
   - add the reduced repro from step 2 as a `tests/*.pas` + `.out` pair, and **re-run `cmake`** so it is actually registered;
   - confirm the whole suite still passes, since a codegen fix that changes a shared helper reaches every test;
   - if the fix changes what a previously-valid program does, that is a `Changed` entry for the release notes, not a silent fix.

9. **Record the lesson.** If the bug came from a decision, add or amend the consequences of the relevant ADR (never its Context or Decision — ADR-0001). If it came from a semantic that was under-documented, add it to `CLAUDE.md`'s "Pascal semantics already encoded" list so the next person does not simplify it back. Keep the negative evidence — the hypotheses ruled out and how — with the test case, so the next session doesn't re-chase them.
