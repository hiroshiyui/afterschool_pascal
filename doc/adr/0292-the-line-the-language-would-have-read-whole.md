# 292. The line the language would have read whole

Date: 2026-09-02

## Status

Accepted, 2026-09-02. Closes the finding
[ADR-0291](0291-a-path-is-not-a-line.md) opened three hours earlier, and does
**not** build the thing that record said it would take.

## Context

ADR-0291 gave the compiler, the JSON library and the language server a path's
capacity where they had held a line's. One truncation survived it, one layer
further in, and that record named it as what was not done:

`lsp/pasls.pas` answers go-to-definition from `pascalc --dump-uses`, whose
output begins with a file table — `file <index> <path>`, one row per file the
translation read — and continues with one `use` row per resolved occurrence.
It read the whole thing with `PasProcess.CaptureLines`, which collects a
command's output into a `StrVec` whose element is `string(ItemMax)`, cutting
every line at 255. Its documentation says so in as many words.

255 is **right** for what that vector holds. Measured on the largest source
here, the dump is 40 821 lines and the longest is 62 characters, so the
element is already four times what a `use` row needs, and widening it to a
path's capacity would take one document's cached answer from 10 MB to 167 MB.

But one row in that dump is not a line, it is a path. So a definition in a
component at a path over 255 characters came back with the path cut,
`PathToUri` escaped what was left, and the server answered a location **in a
file nobody named** — with nothing on either stream to say the answer had been
cut. The same defect ADR-0291 removed from `PathToUri`, arriving from upstream
of it.

ADR-0291 concluded that closing this needed *a capture that separates the file
table or a container generic over its element's capacity*, and sent it to
`doc/roadmap.md` as a design question.

**Neither was needed, and a two-minute probe said so.** Pascal's `readln` reads
a line into a string variable of whatever capacity the reader declared:

```
  var line: string(4096);
  readln(f, line)          { a 407-character line arrives whole }
```

The bound was never the language's. It arrived with the decision to reach for
a library routine whose contract is to cut.

## Decision

**Write the dump to a file and read it with the language.**

- `CompilerCommand` takes a `dumpTo`, empty for every caller but this one. An
  empty one keeps the pipe and `CaptureLines` — right for `--dump-symbols` and
  `--dump-stmts`, whose rows are all names. A named one redirects, and both
  streams go there because this compiler writes its diagnostics to `output`:
  no standard Pascal program has a second one.

- `ReadUses` opens that file, `readln`s each row, and sorts it into **two**
  vectors sized by the two different facts: the `file` rows into a
  `^Vec(PathName)`, and everything else into the `StrVec` it already had. The
  document caches both, and they are emptied together — they are two halves of
  one answer.

- The `use` rows are still cut at `ItemMax`, now **by this program and with
  `substr`** rather than by a routine that did not know what it held. Doing it
  by assignment would make a freak long row §6.4.6 c)'s error and stop the
  server, which is a worse answer than the one it replaces.

- A file table that is not the dense ascending run this indexes it as makes
  `ReadUses` answer false, so the request answers *nothing* rather than a
  location in the wrong file. That is the failure this whole thread is about,
  and it should not be reachable by a parsing slip either.

- `DumpLineMax` is `MaxPath + 32` — `file `, an index, a space, and a path —
  and is **derived** for a reason with teeth: `readln` truncates *silently* at
  the variable's capacity, §6.9.1 skipping the rest of the line. A number
  picked by counting what today's dump needs would be this same defect one
  layer up.

## Evidence

`lsp/sessions/definition_far.jsonl`: a module at a **292-character path**,
imported by a client beside it, with a `definition` request across the two.
The golden was written as a prediction and matched byte for byte.

The mutation is one line — cut every row at `ItemMax` on the way in, which is
exactly what `CaptureLines` did — and it kills `definition_far` **alone**.
`definition_deep` still passes under it, which is the point of having both:
that session's path is 153 characters and its *URI* is 309, so the two
sessions pin two different bounds and neither can stand in for the other.

The fixture has to be a real directory named at length for ADR-0291's reason,
met a third time: the path in that row is the path the **compiler** was handed,
so no fabricated URI can reach it, and no test case can choose its own path.

## What is not done

**`PasFile.ReadLine` and `ForEachLine` still cut at 255 without a word.** They
hand a caller a `FileLine`, and `readln` into it truncates silently, so any
client reading a file with long lines has this defect waiting. It is the same
class and it is *not* fixed here, because no caller in this tree has been
bitten by it — ADR-0116's bar, applied to the module next door. Recorded in
`doc/roadmap.md` rather than fixed on suspicion.

**`PasProcess.CaptureLines` is unchanged and its contract is right.** The
routine did what it says. Nothing about this record is an argument for
widening `ItemMax`, and the measurement above is why.

**No generic container was built.** ADR-0291 proposed one and this is the
record that says it was not needed. `Vec` has been generic over its element
*type* since ADR-0254 and that was already enough: two vectors of different
element types, not one vector of a chosen capacity.

## Consequences

**A library convenience carries a bound; the language underneath it often
carries none.** That is the finding, and it is the third correction in this
chapter of `doc/roadmap.md` to take the same shape — after the `T ! E` entry,
which said a generic could not be written, and the map entry, which said the
map could not hold a URI. Each named a limitation of the language and each was
a limitation of the convenience layer over it. The method that found all three
is the same: **write the probe**, which costs minutes.

**A capacity a reader declares is a decision.** `readln`'s silent truncation is
the mechanism that makes it one, and it is the reason `DumpLineMax` is derived.
Anywhere a capacity is *counted* rather than derived, this record's defect is
one deep checkout away.

**Two sessions, two bounds, and neither is redundant.** It is worth saying
because they look alike from outside — both are `definition` across two files
in a strangely named directory — and a reader tidying one away would delete the
only oracle for one of the two defects.
