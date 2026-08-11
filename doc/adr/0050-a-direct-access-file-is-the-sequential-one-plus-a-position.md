# 50. A direct-access file is the sequential one plus a position

Date: 2026-08-11

## Status

Accepted.

## Context

ISO/IEC 10206:1991 §6.4.3.6:

```
file-type = 'file' [ '[' index-type ']' ] 'of' component-type .
```

"If there is an index-type in a file-type, then that file-type shall be
designated a **direct-access file-type**."

§6.7.5.2 adds `SeekRead`, `SeekWrite`, `SeekUpdate`, `update` and `extend`;
§6.7.6.6 adds `position` and `LastPosition`; §6.7.6.5 adds `empty`.

## Decision

**The index-type in brackets is the whole of the syntax, and one number is the
whole of the mechanism.** ADR-0031 made a `file of T` the text-file machine
with two constants changed; this makes a direct-access file that machine with
one number added — the component the next operation acts on. `struct pas_file`
gained one flag, and the compiler gained one field on `Type`.

**Everything is counted in components, never in bytes.** The index-type is
what §6.4.3.6 gives the positions, so `compsize` appears in the seek and the
length calculation and nowhere else. That is what makes `file ['a'..'z'] of
integer` work without the runtime knowing anything about char.

**The lower bound is folded in the compiler**, exactly as an array subscript's
is. `SeekRead(f, 'c')` on a `file ['a'..'z'] of T` reaches the runtime as 2,
and `position` comes back as 2 and has `ord('a')` added. The runtime never sees
an ordinal, so it needs no notion of one — the same division of labour ADR-0017
gave indexing.

**`position` and `LastPosition` return a value of the index type**, not an
integer. §6.7.6.6 says "a result of type T", and that is the whole reason the
index-type is kept on the `Type` rather than being checked and discarded.

**Seeking one past the last component is legal.** §6.7.5.2's shared
pre-assertion is `0 <= ord(n)-ord(a) <= length(f)`, and the upper end is not a
mistake: that is the append position, and refusing it would leave `SeekWrite`
unable to add a component to a file.

**Update mode is reachable only through `SeekUpdate`.** §6.7.5.2 gives `reset`
and `rewrite` no direct-access variant, so the third mode has exactly one door.
What it buys is `update(f)`: write the buffer variable back over the current
component and **do not advance** — `f.L = f0.L` is the whole difference from
`put`, and it is what makes read-modify-write expressible.

**The stream is opened for both reading and writing when the file-type has an
index-type**, because `SeekUpdate` must be able to turn a file being read into
one being written without reopening — §6.7.5.2 requires it to preserve the
contents, and reopening a file for writing does not.

**`extend` needs no direct-access file.** It is the one of the five procedures
that asks nothing of the file-type, because appending is a sequential
operation; it sits with `reset` and `rewrite` as a third way to open a file.

## Consequences

**The lookahead had to be accounted for twice.** ADR-0021's buffer variable is
one component of read-ahead, so after a fill the stream is one component past
where the program is: `position` subtracts one when the buffer is loaded, and
both `update` and a mid-file `put` step back before writing. That is the only
genuinely new subtlety in the feature, and it is the same one the sequential
code has always had — it simply became observable once a position could be
asked for.

**Nothing about this feature is lexical either.** The five procedures and three
functions are required *identifiers*, not word-symbols, so a valid ISO 7185
program may declare a procedure called `update`; they are recognised only under
`--std=extended` and only when no declaration of the name was found. The
*syntax* is the exception — `file [` cannot occur in ISO 7185 — so the parser
refuses that directly, which is why one program can carry both refusals.

Two identifiers are longer than the longest ISO 7185 word-symbol, so the Pascal
compiler grew a wider pool comparison: `seekupdate` is ten characters and
`lastposition` twelve, and `kwLit` holds nine.

**`text` is never direct-access**, and needs no rule saying so: it has no
index-type, and the checks all ask for one.

**`verify/` gained nothing.** There is no arithmetic here to prove — the seek
is a multiplication by a constant and the fold of a lower bound, both of which
the array rules already cover in the form that matters.

**Twenty-one mutations across both compilers and the runtime, all caught** —
and the runtime ones are where the value of writing them showed. Four escaped
first, all four in `runtime/pasrt.c`, and all four were *state* properties no
program in the corpus had asked about: that `update` does not advance, that a
seek two past the end is refused where one past it is not, that `position`
accounts for the lookahead, and that the buffer variable of a file in Update
mode is fetched rather than left as the last `put` wrote it.

The last of those was a **real bug**, not a missing test: `pas_buffer` treated
Update as writing, so `f^ := f^ + 1; update(f)` read whatever the previous
`put` had left in the buffer. §6.7.5.2's post-assertion for SeekUpdate is
`f" = f.R.first` — the buffer holds the component sought to — and the fix is
one condition. It was found by writing the test that would have killed the
mutation, which is the argument for mutation testing in one sentence.

## What this does not do

**§6.4.3.6's length bound is not checked.** "It shall be an error whenever
`length(f) > ord(b)-ord(a)+1`" — a `file [1..10] of T` may not hold eleven
components. Enforcing it means comparing against the index type's extent on
every `put`, which is a check per component written; it is stated here rather
than silently omitted.

**The mode is not tracked as finely as §6.4.3.6 describes.** The standard's
three modes are Inspection, Generation and Update; this runtime has those, but
a file being updated answers to whichever of the first two a check asks about,
rather than each operation naming the modes it accepts. No program can tell,
because every operation that would care is refused for a different reason
first.
