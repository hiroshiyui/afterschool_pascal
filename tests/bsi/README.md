# The BSI Pascal Validation Suite

```sh
tests/bsi/fetch.sh                        # once; the suite is not committed here
ctest --test-dir build -R bsi --output-on-failure
```

**Fetching is the opt-in.** The case skips when `tests/bsi/suite/` is absent, so
a fresh clone pays nothing; once fetched it runs with every `ctest`, and it
takes minutes where the other 437 cases take twenty-five seconds. It compiles,
links and runs 812 programs. Delete the directory to opt back out.

Version 5.7, **(C) Copyright 1982, British Standards Institution**. 812 programs
across nine categories, written by Brian Wichmann and Z. J. Ciechanowicz to
check a processor against ISO 7185 — and the reason it is here is that **nobody
in this project wrote it**.

## Why it exists

ADR-0085 retired the C++ compiler and with it `selfhost/difftest.sh`, which
compared two independent implementations over 436 sources. What was left —
goldens, the stage-2/stage-3 fixed point, the SMT rules — all share one
implementation, and a golden cannot disagree with the program that wrote it.
Every conformance sweep in `doc/roadmap.md` ends with the same sentence: *no
program in the corpus had written the construct, so all five oracles agreed
with a compiler that was wrong.* This is a corpus that was not chosen here.

It earned that on the first run, finding three defects that the goldens, the
fixed point and 43 proofs all agreed were correct behaviour. All three are
fixed:

- **§6.6.6.4 + §6.7.1** — `succ`/`pred` ran out at a *subrange's* bounds instead
  of its host type's. `tests/trap_succ_subrange.pas` had asserted the wrong rule
  in its own comment, citing §6.6.6.4 without following its cross-reference.
- **§6.8.3.9** — the bounds of a `for` statement were range-checked eagerly,
  where the clause requires it only "if the statement of the for-statement is
  executed".
- **§6.6.4.1** — a program may redefine `write` as its own procedure. `get` and
  `page` already shadowed correctly; the `read`/`write` family did not, because
  the parser recognises those six by name and so decided what they denote in a
  pass with no scope. Fixed by ADR-0087, which moved that decision to Sema —
  and the program the suite is made of, CONF116, had been printing the wrong
  answer with nothing reported.

## The terms

BSI makes the suite available "as is" on three conditions:

- that BSI's copyright is acknowledged;
- that no representation is made which might suggest that a **third-party
  validation** had been carried out;
- that any other representation of the results must describe performance on
  **the whole suite and not simply on selected tests**.

The third is why `run.sh` runs every category on every invocation and prints
all nine counts, and why no document here quotes a number for one category
alone. Passing this suite is **not** a validation, and nothing in this
repository may say otherwise.

The suite is therefore **fetched, never committed** — BSI grants use, not
redistribution — into `tests/bsi/suite/`, which `.gitignore` excludes. That is
the arrangement `doc/vendor/` already has for the standards themselves.
`fetch.sh` pins an upstream commit, because an oracle that changes silently is
not one: a red bar has to be unambiguously a compiler regression.

## What makes it an oracle rather than a report

`expected.tsv` carries a line for each of the 812 programs: its name, what this
compiler does with it, and which category it is in. `run.sh` fails on **any**
difference in either direction.

A program that starts *passing* fails the run just as loudly as one that starts
failing. That is deliberate and it is `verify/`'s rule for a `KNOWN_GAP` that
begins to hold (ADR-0013): the catalogue has then stopped describing the
compiler, and a catalogue nobody has to update is one nobody reads. Fix the
entry in the same change that fixed the compiler, and say in the commit message
which clause moved it.

## The verdicts

| verdict | meaning |
| --- | --- |
| `REJECTED` | the compiler refused the program |
| `SAYS-PASS` | it ran and printed `PASS` — the conformance tests are self-checking |
| `SAYS-FAIL` | it ran and printed `FAIL` |
| `NOT-DETECTED` | it printed `ERROR NOT DETECTED` — an error the standard permits a processor to miss |
| `TRAPPED` | it stopped with a run-time error |
| `RAN` | it completed with nothing above to say — the normal answer for `IMPDEF`/`IMPDEP` |

What each verdict *should* be depends on the category, and the suite's own
`DOC/README.TXT` is the authority: `CONFORM` must reach `SAYS-PASS` (except
`CONF024`, the minimal program, which writes nothing); `DEVIANCE` must be
`REJECTED` or `TRAPPED`; `LEVEL1` must be `REJECTED` entirely, this being a
level 0 processor (`doc/implementation-defined.md` §1); `ERROR` is pairs of a
correct pretest and a test, where `NOT-DETECTED` is permitted but should agree
with the list of unreported errors that document carries.
