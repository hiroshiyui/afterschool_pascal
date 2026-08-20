# ADR-0141: One rule for saying a routine may have failed

Date: 2026-08-20

## Status

Accepted. Answers the fifth of the seven open questions in `doc/roadmap.md`.
Records a convention rather than changing the compiler; `lib/dialect/README.md`
is the author-facing form.

## Context

`doc/roadmap.md` §5 observes that the dialect was pulled rather than designed —
every feature demanded by the foreign interface or by the library built on it,
nothing speculative — and that nobody had stepped back to ask whether the
pieces form a language. It names the sharpest instance:

> the dialect now has two ways to say "this may have failed": an optional (`?T`
> — absence) and a result record (ADR-0120 — absence with a code).
> `lib/dialect/pasfs.pas` uses both, `OptPathName` inside and `PathResult` out.
> Either there is a rule an author can apply — *absence is not a failure* is the
> candidate — or users meet both idioms and learn neither.

Surveying all seven modules, there are not two idioms. **There are four**, and
the fourth is not about failure at all:

| Shape | Routines | What it says |
| --- | --- | --- |
| `ErrorCode` | 9 | the routine acted; it worked or here is why not |
| `?T` | 1 | there is a value, or there is not, and there is nothing to add |
| a result record | 9 | there is a value, or here is why there is not |
| `boolean` | 4 | a question about the world, which has no failure of its own |

Plus two conveniences with fixed names — `XOr(r, whenBad)` for a caller with a
default, and `ResultText(r)` for one composing a message.

## Decision

**The rule is two questions, asked in order, and it is writable:**

1. **Is there a value to return?** No → `ErrorCode`.
2. **Can the value be missing for a reason the caller could act on?**
   No → `?T`. Yes → a result record.

A routine that merely *asks about the world* — `Exists`, `Defined`, `AtEnd`,
`Failed` — answers `boolean`, because there is no failure distinct from the
answer and inventing an `ErrorCode` for one would give the caller a third state
to handle for nothing.

*Absence is not a failure* was the roadmap's candidate slogan and it is correct
— **for the second question's "no" arm only**. It was never a rule for the
whole surface, which is why applying it alone would not have told an author
what to do about `Remove`, which has nothing to return, or `Exists`, which
cannot fail.

**Two rules of spelling**, both already followed everywhere and neither
previously written down:

- the tag of a result record is spelled **`ok`**, in every module, and the
  payload carries each record's own name;
- an extractor is **`XOr(result, default)`**, result first.

That matters more than it looks: ADR-0118 makes the tag authoritative, so
`r.path` when `r.ok` is false stops the program. The caller's discipline is
enforced by the language rather than remembered, which is what makes a result
record better here than the `(value, code)` pair every C interface uses — and
it is also why the tag having one spelling is worth a rule.

## Consequences

**The coherence question is answered in the affirmative**, which was not the
foregone conclusion: the roadmap's own framing allowed for "or users meet both
idioms and learn neither". Four shapes with a two-question discriminator, no
overlap, and all 35 exported routines classify — 9 `ErrorCode`, 9 result
records, 4 `boolean`, 1 optional, and 12 that cannot fail at all (5 extractors,
3 renderers, and 4 total functions). The pieces do form a language,
at least here.

**One routine violates the rule, and it cannot be fixed.** `PasEnv.Lookup`
returns `?EnvText` — arm 3, absence with nothing to add. It has a third outcome:

```
$ PROBE=$(python3 -c "print('x'*5000)") ./probe
runtime error: a string of length 5000 does not fit a capacity of 4096
```

An environment value longer than `MaxValue` **stops the caller's program**. By
the rule it should be a result record with `errFull`, which is exactly what
`PasFS.WorkingDirectory` does for the same situation. The asymmetry is
structural rather than an oversight: `getcwd` is *lent a buffer* and reports
`ERANGE`, while `getenv` returns a pointer to a string of a length nobody
stated, the length is discovered inside the boundary conversion, and the
dialect has no result form that could receive an unmeasured one — `?string`
without a capacity is a parameter form and not a result type, which was probed.

So the rule gains a clause it would not otherwise have: **where a boundary
cannot report a failure, say so at the routine.** The alternative is a
truncation nothing reports, and `PasEnv`'s own comment already rejects that,
citing §6.4.6. `PasOS.ErrorNumberText` has the same shape against `strerror`
and is unreachable in practice rather than guarded.

**Nothing checks any of it.** This is a convention and not a gate: a module
returning a result record whose tag is spelled `success` would compile, link and
pass every test here. That is recorded in `doc/sop.md` §7 rather than fixed,
because the check worth writing is not obvious — the shapes are ordinary Pascal
and a linter over an interface is a tool this repository does not have.

## What this does not do

**It does not add a language feature.** Every shape above is expressible today,
which is the finding rather than a limitation: the roadmap asked whether the
pieces cohere, and they do without anything new. In particular this is **not**
an argument for error unions or a `try` form — those would replace a convention
that works with syntax, and the case for them has to be made on its own.

**It does not settle the wider §5 question.** §5 asks whether the dialect
coheres *as a whole*; this answers it for the one instance §5 called sharpest.
Optionals against pointers, slices against strings, and `int64` against
`integer` are three more places where two things nearly overlap, and none has
been examined this way.

**It does not fix `PasEnv.Lookup`**, and the reason is above. Raising
`MaxValue` moves the boundary without removing it, which is why it was not
done.
