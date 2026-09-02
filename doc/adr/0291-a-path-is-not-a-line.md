# 291. A path is not a line, in three programs

Date: 2026-09-02

## Status

Accepted, 2026-09-02. Closes `doc/roadmap.md`'s finding *`JsonLine` is 255
characters and a URI is not a line*, and opens one in its place: see *What is
not done*.

Forced an **out-of-cycle reseed**, the second after ADR-0268's, for the reason
that record gives: a constant the compiler reads about *itself* is one the
running compiler was built with, so raising it in the source raises it for
every program except this one.

## Context

`doc/roadmap.md`'s language-server chapter carried a finding for eleven
increments: three modules pick 255 for "a string a caller hands over in one
piece", which is right for a message and wrong for an identifier that happens
to be a path. It was recorded as a bound that had not yet cost anything.

It had. Reading the code rather than the entry found three separate
truncations, in three programs, and the entry named the least of them.

**The library refused, and did it by stopping the program.** `PasJson`'s
`JsonNewText`, `JsonTextAdd`, `JsonParse` and `JsonCharsAddLine` each took a
`JsonLine`, and `PasLspDiag.DiagPublish` took one for a URI. A caller holding
a wider string met §6.4.6 c)'s error at the call — `a string of length 300
does not fit a capacity of 255`, and the program stopped. Not a truncation and
not a diagnostic.

**The server dropped the document.** `DocUri = JsonLine` was *deliberate* and
its comment said so: `DiagPublish` took one, so a URI the server could hold
and that module could not would have been a truncation at the boundary rather
than a refusal at the door. The refusal is a line on standard error and no
`publishDiagnostics` ever — so a Pascal file nine directories deep opens in an
editor and the server never says anything about it, on a stream the editor
hides.

**And the server answered with a URI naming a different file.** `PathToUri`
appended under a `length(out) < LineMax` test and simply stopped at 255. That
is the one that costs most: go-to-definition returns a location, a client
resolves it, and nothing on either stream says the answer was cut.

**The compiler had the same bound, and it was the sharpest.** `nameStr` was
`string(strMax)` — 255 — and its own comment read *"a file name or a
command-line argument"*. So `pascalc` at a 310-character path reached
`pas_str_fits` and stopped, **naming no file**, from a program whose whole job
was to compile one. `bindNameCap`, the capacity of `BindingType.name` and
therefore of every argument this compiler reads (ADR-0081), said in as many
words that it was *"a file name's worth"* while being 255, which is not one.

Two comments in this tree had already walked up to it. `compiler.pas` says of
`envMax`: *"Not nameStr, which is 255 and is the bound on one path: a list of
them is longer by however many there are … so reading a list into a
name-sized string would turn a long variable into a trap rather than a
diagnostic."* It names the hazard and the number and stops one step short of
asking whether the number is right for one path either. And `pasls.pas` says
of `ItemMax`: *"Four of the twelve findings this program has produced are
bounds chosen by counting what the largest thing in the tree needed at the
time, and the largest thing in the tree was a test case."*

Every path any harness here passes is short, so no oracle could see any of it.

## Decision

**A path gets its own capacity, derived from what a path is.**

- **The library's one-piece string parameters are schematic.** `s: string`
  rather than `s: JsonLine` at the five formals above, so the capacity is the
  caller's. Nothing is spelled and nothing is reserved — ADR-0115 admitted a
  variable-string value parameter of a different capacity, and `lib/pasfile.pas`
  had been writing `content: string` since it was written. `JsonLine` stays
  exported as a ready-made capacity for a caller that wants one, which is
  exactly what ADR-0290 did with `MapKey`.

- **The server's `UriMax` is derived and not chosen**: `7 + 3 * MaxPath`, being
  the scheme's seven characters and a path in which every byte percent-escapes.
  Deriving it is what lets `PathToUri` concatenate with no bound test at all —
  the bound cannot be met rather than being met and reported. If the derivation
  is ever wrong the concatenation traps, which is the failure to prefer over a
  URI silently cut.

- **The compiler gets `pathMax = 4096` and `pathStr`**, and `bindNameCap` is
  derived from `pathMax` so that its sentence and its number agree. `nameStr`
  stays at `strMax` and keeps the three uses that really are names — a word the
  formatter writes, a real written back by `writestr`. 4096 is Linux's
  PATH_MAX and the roomiest of the shorter limits every other system has, which
  is the reading `PasFS.MaxPath` already took.

**The reseed is not incidental.** `BindingType`'s capacity for a program is
decided by the compiler *translating* it, so `build/bin/pascalc` — built from
`seed/*.ll` — kept reading its own arguments into a 255-character field however
the source read. A stage-2 compiler built from the fixed source handled a
359-character path while stage 1 did not, which is how this was diagnosed.
ADR-0126's sentence, written about a fixed buffer, is the same one: *the array
that has to hold this source is the seed's, so raising the constant here does
not raise the one that matters.*

## Evidence

Four mutations, four different cases, and each fails for its own reason:

| Mutation | Killed by |
| --- | --- |
| `pathMax` back to 255 | `long-path`, 3 of 3 claims |
| `JsonNewText`'s formal back to `JsonLine` | `lib_json_wide`, at the trap |
| `DocUri` back to `JsonLine` | `long_uri` — no `publishDiagnostics` at all |
| `PathToUri`'s two `< LineMax` tests restored | `definition_deep`, alone |

`long-path` is a **new gate** and needs to be one for `stale-component`'s
reason, met a second time: **no test case can choose its own path.** Every case
here is compiled where it sits, and a harness that passes a short path cannot
ask this question. It makes three claims at a 301-character path — a source
named on the command line, a module found under an `--import-path`, which is a
path the compiler *computed*, and a diagnostic that still names the file.

The two sessions were both written as **predictions**: the golden was composed
from what the protocol requires and matched byte for byte on the first run,
rather than being taken from what the server did.

`definition_deep` is worth its own paragraph, because the obvious fixture does
not work. Reaching `PathToUri` needs a file the compiler actually read, and a
directory named at length makes the *path* long as well — which crosses
`PasStrVec.ItemMax` below and would have tested the wrong bound. So the
directory is named in Japanese: 81 bytes of name percent-escape to 243
characters, so the URI passes 255 while the path stays at 153. The round trip
is pinned with it — the server decodes the escapes to find the file and
encodes them again to name the answer.

## What is not done

**`PasStrVec.ItemMax` is 255 and a dump line carrying a path crosses it.** The
server reads `--dump-uses` into a `StrVec`, whose element type is
`string(ItemMax)`, and the file table at the head of that dump holds absolute
paths. A path over 255 characters is cut there, before `PathToUri` is reached.

It is **not** the same defect and must not be fixed the same way. Measured on
the largest source here, that dump is 40 821 lines whose longest is 62
characters: 255 is already four times what every line but one kind needs, and
widening the element to `pathMax` would take a document's cached answer from
10 MB to 167 MB. The bound is right for what the vector holds and wrong for one
row in it, so the fix is either a capture that separates the file table or a
container generic over its element's capacity — `Vec` is already generic over
the element *type* (ADR-0254), and what is missing is a routine that can fill
one without naming the capacity. That is a design question with a caller now,
which is the shape ADR-0116 asks for; it goes to `doc/roadmap.md` rather than
being answered here.

**No specification clause changes.** AP 5.1 i) says this language's
specification does not specify representation or storage layout, and a capacity
in characters is one; §6.4.3.4 leaves `BindingType.name`'s string-type
implementation-defined, so the number lives in
`doc/implementation-defined.md` E.14, which is updated. Nothing here is a
feature and nothing is spelled.

**`strMax` is unchanged.** An identifier or a character-string is still bounded
at 255 and still diagnosed rather than truncated (ADR-0110); that is a lexical
limit with its own reason, and confusing it with a path bound is what this
record is about.

## Consequences

**A comment that names a hazard is not a check.** Both comments quoted above
describe the trap correctly, in the right file, next to the wrong number.
Neither could fail.

**The seed carries values, not only code**, and the class is narrower than it
first looks. ADR-0126 recorded it for a fixed buffer's capacity; the general
form is *a constant that shapes a type this compiler **synthesises** and also
declares a variable of*. `BindingType` is the whole of that class today —
`Arg` declares one to read the command line (ADR-0081) — and the near misses
are instructive. `dateLen` and `timeLen` shape a synthesised type too and are
**not** affected, the compiler emitting them into the program it compiles and
declaring no `TimeStamp` of its own. An ordinary array bound written in the
source is not affected either. All three look alike where they are declared
and differ in who evaluates them, which is why the question has to be asked
rather than seen. `doc/sop.md` §7 carries it.

**Thirty gates.** `long-path` runs under `ctest` like all but `model-drift`,
and costs 0.2 s.

**A test fixture may be an artefact rather than a program.** The Japanese
directory name under `lsp/sessions/workspace/` is the case; the two modules in
it only have to declare something worth going to. That is `stale-component`'s
shape again — what is being tested is a property of the *file system* the
compiler is run against, and it cannot be written in Pascal.
