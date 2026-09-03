# 305. The capacity is the caller's, and the language already reports the cut

Date: 2026-09-03

## Status

Accepted, 2026-09-03. Closes `doc/roadmap.md`'s row *What a program reads can
be cut without a word* in the chapter *What would make this practical to pick
up*, in both of its halves — the library half by ADR-0291's mechanism, the
language half by a probe that found the facility already there.

## Context

The row is the warning ADR-0292 closed with, and it states one thing from the
user's side: **a line longer than a number the program did not choose is lost,
and nothing says so.**

`PasFile.ReadLine` took a `var line: FileLine` and `ForEachLine` handed its
`visit` a `FileLine`, both 255. A caller reading a file with long lines got a
prefix, `readln` skipped the remainder, and no routine here answered anything
about it. ADR-0292 recorded that and declined to fix it on ADR-0116's bar —
no caller in this tree had been bitten — while its own consequences section
said the general form: *anywhere a capacity is counted rather than derived,
this record's defect is one deep checkout away.* Counting is exactly what
`FileLineMax = 255` is.

The row named two halves and said the second had **not been probed**. It had
been asserted twice, though: ADR-0292's decision paragraph says `readln`
truncates silently at the variable's capacity and gives §6.10.1 as the reason,
which is true, and stops there.

## Decision

**The bound on a line is the caller's, and the language reports the cut.**

- **`ReadLine` takes `var line: string`.** ADR-0291's mechanism unchanged:
  ADR-0115 admits a variable-string parameter of any capacity, so a caller
  reading into `string(4096)` gets 4096 characters and one reading into
  `string(8)` gets eight. `FileLine` stays exported as a ready-made capacity,
  as `JsonLine` did (ADR-0291) and `MapKey` before it (ADR-0290).

- **`ForEachLine` takes the buffer it reads through**, `var buf: string`, and
  `visit`'s own formal becomes schematic. A visitor is called with a value, so
  the capacity cannot come from the visitor; it has to come from a variable
  somebody declared, and the caller is the only one who can. §6.7.3.6's
  congruity then requires the actual procedure's formal to be written
  `string` too, which a probe confirmed before the module was touched.

  The alternative shape was an integer capacity — `ForEachLine(path, 4096,
  visit)` with a local `string(cap)`, which §6.2.3.8 b) admits and which was
  probed and works. It was **rejected for ADR-0292's own reason**: a number at
  a call site is a counted capacity, and a variable's declaration is a derived
  one. It also disagrees with every other reader in this library —
  `NetReadLine`, `StreamReadLine`, `ReadAllText` all take the caller's string.

- **The language half needs nothing built.** `read(f, s)` stops at the
  capacity **or** at the line's end, whichever comes first (ISO/IEC
  10206:1991 §6.10.1 f)), so `eoln(f)` immediately afterwards is false exactly
  when something was left over, and `readln(f)` then skips it. Three tokens,
  no flag, no new required identifier, and no clause of the specification
  moves. `readln(f, s)` is the one that cannot report, because it does the
  skipping itself — which is the whole of what §6.10.1 says and was never a
  gap in the language.

  So the finding is that it was **documentable and not missing**, and it is
  now documented at the routines that do the truncating, which is where the
  reader who needs it is standing.

## Evidence

`tests/extended/lib_file.pas` gains three claims and eight golden lines:

```
narrow: TRUE [a line l] 8
wide: TRUE [a line longer than eight] 24
...
whole=TRUE [short]
whole=FALSE [a line l]
```

The first pair is the same line of the same file read into `string(8)` and
into `string(300)`, which is the row's complaint answered: the number that
decided is the one the program wrote. The `whole=` pair is the language half,
and it is the sharper of the two — `eoln` is true after the line that fitted
and false after the line that did not, with nothing in the library involved.

| Mutation | Killed by |
| --- | --- |
| `ReadLine`'s formal back to `var line: FileLine` | `lib_file`, at `wide:` — the 24-character line comes back as itself either way at 255, so the case reads it into `string(300)` and the *narrow* claim is what a `FileLine` formal cannot express: the golden's `[a line l]` becomes `[a line longer than eight]` |
| `ForEachLine`'s buffer removed and a local `FileLine` restored | `lib_file`, at the two `ForEachLine` sweeps, which differ from each other only in the capacity of the buffer they were handed |

The probe that settled the language half is four lines and is in the case, so
it is now an oracle rather than an afternoon's finding:

```pascal
read(g, small);
writeln('whole=', eoln(g), ' [', small, ']');
readln(g)
```

## What is not done

**`ReadLine` and `ForEachLine` still do not report a truncation themselves**,
and that is deliberate. Adding an out-parameter to both would put the
answer in two places — the language's and the library's — and the library's
would be the copy free to drift. What the module does instead is say, at the
routines, what to write when the answer matters; a caller who needs it is
three tokens from it and is not reading through a convenience layer that
cannot be right about everything.

**`FileLineMax` and `FileLine` are unchanged and still exported.** They are a
capacity a caller may want and no longer a bound a caller is given, which is
the same distinction ADR-0290 and ADR-0291 each drew.

**No specification clause changes**, and none was written. AP 5.1 i) leaves
representation and storage layout unspecified and a capacity in characters is
one; §6.10.1 is ISO/IEC 10206:1991's and this language contains it unaltered.

**`PasStrVec`'s `ItemMax` is still 255** and is still right for what that
vector holds — ADR-0292 measured it and nothing here changes the measurement.

## Consequences

**A convenience layer's bound is the caller's decision or it is a defect.**
This is the fourth correction in this chapter to take one shape (ADR-0290,
ADR-0291, ADR-0292 and now this), and the shape is: the language underneath
carries no bound, the convenience over it carries one, and the entry blames
the language. Two callers moved here and both had been writing `FileLine`
because the interface asked them to.

**A row that says a thing has not been probed is a row nobody has probed.**
The roadmap's own lesson, met again: the language half of this row took four
lines and a rebuild, and the answer was that the facility exists and is
spelled `read` and `eoln`. Two documents had walked past it — ADR-0292 cites
§6.10.1 for the truncation and does not read the sentence beside it.
