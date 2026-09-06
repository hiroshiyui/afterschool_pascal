# Implementation-defined and implementation-dependent behaviour

This document says what this processor decides where a clause of ISO 7185 or
ISO/IEC 10206:1991 leaves the decision to it. It defines every
implementation-defined feature, describes the treatment of every
implementation-dependent one, names each error it does not report, and
describes the extensions it accepts.

Both standards list their own features again in informative annexes, and the
tables below follow that numbering so an entry can be found from the standard
rather than from this document's own headings. Where the two standards ask the
same question, the answer is given once and both entry numbers are cited.

## 1. There is no compliance statement

**Withdrawn** (ADR-0232). Clause 5.1 of ISO 7185 requires a processor that
purports to comply to do so "only in the following terms", and prescribes the
sentence; this document carried that sentence, in both standards' wordings, and
claimed level 1.

Afterschool Pascal is a Pascal *dialect* and no standard governs it. §6.1.2 of
ISO/IEC 10206:1991 reserves ten word-symbols that a valid ISO 7185 program may
use as ordinary identifiers, and this processor reserves all of them — so a
conforming ISO 7185 program with a record field called `value` is refused, and
BSI's CONF005 was written in 1982 to check exactly that. A processor that
cannot compile CONF005 does not comply with ISO 7185 at any level, and the
claim is withdrawn rather than reworded.

What the document keeps is everything else, because it is still useful and
still true: this language contains Extended Pascal, so every clause below
describes a decision this compiler actually makes. §6's restrictions list in
particular is a description of a dialect whether or not a standard demands one.

The conformant array parameters of ISO 7185 §6.6.3.6 e), §6.6.3.7 and §6.6.3.8
— which were the whole of clause 5.1 a)'s difference between its two levels —
are accepted (ADR-0153):

```pascal
function total(var a: array [u..v: integer] of integer): integer;
```

One compiled body serves every extent, `u` and `v` denote the smallest and
largest values of the index-type the *actual* possesses, and §6.6.3.8's
conformability decides which actuals fit. The abbreviated form
`array [u..v: T1; j..k: T2] of T3` and the nested full form are equivalent, as
§6.6.3.7 says they are, and both are accepted.

## 2. Implementation-defined features

ISO 7185 Annex E lists eighteen and ISO/IEC 10206:1991 Annex E thirty-four.
Where both ask the same question the answer is given once.

### 2.1 Lexis

| 10206 | 7185 | Feature | This processor |
|---|---|---|---|
| E.1 | E.1 | which char values the string-elements denote | A string-element is one **byte** of the source, denoting the char whose ordinal is that byte's unsigned value; `''` denotes ordinal 39. A multi-byte UTF-8 character is therefore several string-elements, and a literal holding one byte of it is a `char`. |
| E.2 | E.2 | provision of the reference tokens `^`, `[`, `]` and of the alternative token `@` | The three reference tokens **are** provided. The alternative token `@` is **not**: it is rejected as an unexpected character. |

E.2 asks about four tokens and no more. The clause it comes from, §6.1.9
(§6.1.11 in ISO/IEC 10206:1991), *requires* the other alternative
representations of every processor whose character set has the characters —
`(.` for `[`, `.)` for `]`, `(*` and `*)` for the braces — and requires that
"the corresponding tokens or separators shall not be distinguished". All four
are provided here, so `a[2.)` is a legal subscript; `tests/lexalternatives.pas`
is what says so. That is not an entry in this document, because it is not a
choice the standard leaves open.

An earlier version of this table said the opposite: that `(.` and `.)` were
implementation-defined and not provided. It also listed a double quote among
the tokens, which is an artefact of reading an extraction of the PDF — the
standard writes the pointer symbol as an up-arrow, and the arrow arrives in the
text layer as a quote. Pascal has no double quote anywhere; `"` in a program is
an unexpected character, and inside a literal it is an ordinary
string-character (E.1).

### 2.2 The required constants and types

| 10206 | 7185 | Feature | This processor |
|---|---|---|---|
| E.3 | E.8 | `maxint` | `2147483647`. The integer type is −maxint..maxint (ADR-0014), so −2147483648 is not a value of it: the literal is refused at compile time and `-maxint - 1` traps. |
| E.4 | E.3 | the real-type | IEEE 754 binary64, **at every stage of an expression and not only in storage** — which is a requirement on the target rather than on the type, and the reason an i386 this compiler emits for is required to have SSE2 (ADR-0346). |
| E.5 | — | `minreal` | `2.2250738585072014e-308` — the smallest positive *normal* value, `DBL_MIN`. |
| E.6 | — | `maxreal` | `1.7976931348623157e308` — `DBL_MAX`. |
| E.7 | — | `epsreal` | `2.220446049250313e-16` — 2⁻⁵², `DBL_EPSILON`. |
| E.8 | E.9 | accuracy of the real operators and functions | The host C library's, unrounded and unmodified; a real literal is carried as its source text into the IR and converted by the assembler (ADR-0025). |
| E.9 | E.4 | the char values | The 256 byte values. |
| E.10 | E.5 | their ordinal numbers | The byte itself: `ord(chr(n)) = n` for 0..255. |
| E.11 | — | `maxchar` | `chr(255)`. |
| E.12 | — | the complex values | A pair of binary64 values, `<2 x double>` (ADR-0049). |
| E.13 | — | accuracy of the complex operators and functions | C99's, `csqrt`/`clog`/`catan` being called rather than re-derived; the principal values are C99's. |

Each of `minreal`, `maxreal` and `epsreal` is the shortest decimal that
round-trips to the binary64 value it names, and the same characters appear in
both compilers (ADR-0062).

**An i386 this compiler emits for has SSE2**, and that is a decision rather
than an observation (ADR-0346). `i386-pc-linux-gnu` is one of the three
targets `--target=` admits, and clang's own default processor for it is
`i686`, whose x87 registers are eighty bits wide — so an intermediate value
would be wider than the type holding it, and two of this document's own
answers would stop being true on that one target. §6.7.6.3 defines `round(x)`
as equivalent to `trunc(x ± 0.5)`, and the two disagree at
`-0.49999999999999994`, where the sum is exactly `-1.0` as a double and a
shade above `-1` in a register; and D.32 makes `sqr(x)` yielding a value the
type does not have an *error*, detected by asking whether the result is
infinite, which a fifteen-bit exponent prevents — so `sqr(-1e200)` prints
where every other target here stops. `tools/pascalcc` names `-march=pentium4`
for this triple and for no other; the processor is from 2003, and a missed
error condition on one target is not something this dialect will carry to
reach older ones.

### 2.3 Output

| 10206 | 7185 | Feature | This processor |
|---|---|---|---|
| E.24 | E.10 | default TotalWidth for integer | The exact number of characters the value needs — its digits, preceded by `-` when negative. Nothing is padded. |
| E.25 | E.11 | default TotalWidth for real | ExpDigits + 17: nineteen characters, or twenty when the exponent needs three digits. DecPlaces follows §6.10.3.4.1's `ActWidth − ExpDigits − 5`, giving twelve fractional digits. `tests/extended/writereal_width.pas` measures the representation rather than pinning its digits, which is what makes this an answer and not a claim. |
| E.26 | E.12 | default TotalWidth for Boolean | The length of the word written — 4 for `TRUE`, 5 for `FALSE`. Nothing is padded. |
| E.27 | E.13 | ExpDigits | **2, except that an exponent of magnitude 100 or more is written with 3.** §6.10.3.4.1 reads as though ExpDigits were a fixed number; it is not here, because C's `%E` writes as many digits as the exponent needs. Stated as a deviation in ADR-0064. This wording was right and the code was not: the width was taken from the magnitude of `log10` rather than from the exponent written, which differ for a value in [1e-100, 1e-99), and the field came out one character too wide. Nothing had probed it. `tests/extended/writereal_width.pas`. |
| E.28 | E.14 | the exponent character | `E`, upper case, always. |
| E.29 | E.15 | the case of `True` and `False` | Every letter upper case: `TRUE` and `FALSE`. §6.10.3.5 makes writing a Boolean equivalent to writing that word as a character-string, so §6.10.3.6 decides the rest: with a width above the word's length it is padded on the **left**, and with a width between 1 and the word's length "the first through TotalWidth-th characters" are written — so the leftmost survive and `true:2` is `TR`. At width 0 nothing is written. This row said "truncated from the left", which names the opposite end and would make `true:2` read `UE`; the code was never wrong, only the sentence. `tests/extended/fieldwidth.pas` has had the four widths since it was written, which is why this is a slip in the sentence and not in anything a test could see. |

### 2.4 Files and binding

| 10206 | 7185 | Feature | This processor |
|---|---|---|---|
| E.15 | E.7 | when file operations are actually performed | At the call, through C stdio; `reset`, `rewrite` and `extend` open or reopen the stream, `get` and `put` transfer one component. One component of lookahead is held (ADR-0021), so the stream is one component ahead of the program. |
| — | — | a textfile whose last line has no line terminator | §6.4.3.5 says every line ends in one, and such a file is read as though it did: the terminator is supplied when the file is read, so the last line is a line and `eoln` becomes true at its end. Reading past that is end-of-file, which is D.97's error and stops the program (ADR-0021). Recorded here on 2026-09-02, when `doc/roadmap.md`'s known-limitations chapter stopped listing deviations from the standards. |
| E.14 | — | the variable-string-type of `BindingType.name` | `string(4096)`, which is a file name's worth: Linux's PATH_MAX and the roomiest of the shorter limits every other system has. It was `string(255)` while its own comment said *a file name's worth*, and since this field is the only channel a program has to its command line (ADR-0081) an argument longer than that stopped the compiler rather than being reported (ADR-0291). |
| — | — | the additional fields of `BindingType` (§6.4.3.4 NOTE 7) | One: `writable`, of type `Boolean`, true exactly when the bound external entity could be opened for writing at the moment `binding` was applied — and false where the variable is bound to nothing, as `bound` is. It is §5's extension rather than an implementation-defined choice, and it is here because a reader looking up binding will look here. AP 6.4.3.4.7, ADR-0240. |
| E.16 | — | what `bind(f, b)` binds to | The file whose pathname is `b.name`, with trailing spaces trimmed; the file is thereafter an external one, as a program parameter is (ADR-0052). **The variable is bound to an external entity when that entity exists**, asked whenever `binding` is called — so `bound` is false for a name nothing is at, and true for the same variable once `rewrite` has created the file. §6.7.5.6 makes the binding implementation-defined and its NOTE 2 makes `binding(f).bound` the test of success, which is what lets a conforming program ask whether there is anything to read before `reset` stops it. Readability is not asked: that is the open's own question. The name is kept whatever the answer, so an unchecked `reset` still stops at the file that was named rather than reading a scratch file, and a second `bind` is the dynamic-violation only when the first is bound to something (ADR-0172). `tests/extended/bind_missing.pas`. |
| E.19 | — | the value `binding(f)` returns | `bound` says whether the variable is bound to an external entity and `name` is the pathname it is bound to, or the null string when it is not. **A program-parameter that was given a command-line argument is bound, and `name` is that argument** — §6.7.6.8's NOTE 2 makes `binding` the way "to determine the result of any binding of program-parameters prior to activation of the main program", and it is the only channel either standard gives a program to its own command line (ADR-0081). A program-parameter with no argument is unbound, which is how a program counts the arguments it was given. **`input` and `output` answer as unbound**: they are bound to an external entity, but to one with no pathname, and reporting a name `bind` could not reproduce would be worse than reporting none. `unbind` clears the binding §6.12 made, as it clears one the program made. `tests/extended/bindprogparam.pas`. |
| E.17 | — | "current date" for `GetTimeStamp` | `SOURCE_DATE_EPOCH` when that variable holds a value the whole of which parses, read as UTC; the system clock otherwise, also read as UTC (ADR-0065). |
| E.18 | — | "current time" | As E.17 — one clock reading fills all eight fields. |
| E.20 | — | the length of `date(t)` | 10, fixed. |
| E.21 | — | the representation `date(t)` returns | ISO 8601 `YYYY-MM-DD`, zero-padded. |
| E.22 | — | the length of `time(t)` | 8, fixed. |
| E.23 | — | the representation `time(t)` returns | ISO 8601 `HH:MM:SS`, 24-hour, zero-padded. |
| E.31 | — | binding of module parameters | `input` and `output` denote the required text files and are the only way a module reaches the standard streams. **Any other module-parameter is bound to nothing** and behaves as an internal scratch file (§6.11.1 NOTE 6, ADR-0053). |
| E.32 | E.18 | `reset`, `rewrite`, `extend` on `input` | `reset(input)` **leaves the file exactly as it is** — the standard input cannot be repositioned, and clearing the lookahead would lose a character the stream has already consumed (ADR-0073), and `tests/resetinput.pas` pins it. `rewrite(input)` and `extend(input)` stop the program with a run-time error — `tests/trap_rewriteinput.pas` and `tests/extended/trap_extendinput.pas`. |
| E.33 | E.18 | the same on `output` | `rewrite(output)` and `extend(output)` have no effect at all — no truncation, no reposition, and the line state `page` consults survives, which `tests/rewriteoutput.pas` and `tests/extended/extendoutput.pas` pin by calling `page` afterwards. `reset(output)` stops the program with a run-time error (`tests/trap_resetoutput.pas`). |
| E.34 | E.17 | binding of program parameters | Bound in the order written, skipping `input` and `output`, to the command-line arguments `argv[1]`, `argv[2]`, … as pathnames. Surplus arguments are ignored; a missing one is a run-time error at the first `reset`, `rewrite` or `extend` of that file. `input` and `output` are the standard streams and consume no argument, and neither does a parameter that does not possess a file-type — see F.10 in §4. |
| — | E.6 | the characters prohibited from textfiles | Exactly one: `chr(10)`. See §3's F.1 for what attributing it does. |

### 2.5 Accepting the program-components separately

§6.13 asks with a *should* that a processor be able to accept the
program-components of a program-block separately, and says nothing about how.
This processor does, and this is the how (ADR-0079).

A component that declares no main-program-declaration is translated with `-c`
and becomes an object file. A component that imports an interface is given the
supplying component with `--import <file>`, repeated once per component, and
the objects are named alongside its own source so they reach the linker. The
stage-1 compiler takes `--import` too, once per component: it used to take them
concatenated into a single program parameter, ISO 7185 giving a program no way
to open a file whose name it computes, and since ADR-0081 it names them
(§6.7.5.6's `bind`).

**A translation takes at most 32 `--import` arguments and 72 command-line
arguments in all**, so a program-block with more than 32 supplying components
cannot be translated here. §6.13 puts no limit on how many a program-block has,
so both numbers are this processor's, and each is *reported* — `more than 32
--import arguments`, `more than 72 arguments` — rather than truncating the
list. They are one limit rather than two: an import costs two words of the
command line, so the second is derived from the first (ADR-0235). They were 8
and 24 until a program with ten modules asked.

**The artefact is the supplying component's source.** No interface file format
is defined, and none is needed: §6.11.1 puts the whole of what a module exports
in its module-heading, so `--import` reads that heading and nothing else of the
component. The consequence a user sees is that a heading's own errors are
reported again in each component that imports it.

**An object built from an older heading is refused** (AP 6.13.2, ADR-0245).
Two translations may read two different headings for one module and agree
about every name in them, and what stood here said that nothing detected it —
which cost a wrong answer with a zero exit status and no diagnostic anywhere.
A digest of the module-heading's **tokens** is now part of the name of that
module's activation procedures, which §6.13 already requires the components to
agree on, so the linker refuses the mixture and `tools/pascalcc` says which
module and why. Tokens rather than text: a heading differing only in a comment,
a separator or its layout is the same heading, and a change confined to a
module-block is not a change to a heading at all.

**A component may also be found rather than named** (ADR-0244). An `import`
naming an interface no `--import` supplied is looked for as
`<directory>/<interface name>.pas`, with the name folded as §6.1.2 folds every
identifier, in three places and in this order: the directory the source being
translated is in, each `--import-path <directory>` in the order written, and
each entry of the environment variable `AFTERSCHOOL_PASCAL_PATH`, which holds
directories separated by `:`. An empty entry is skipped rather than taken for
the working directory. The first directory holding the file wins, and the
search is transitive — a component found this way has its own imports resolved
before it, which is what makes the list an activation order for §6.2.3.6.

Three things about it are this processor's and are not obligations of the
standard. The file is named after the **interface** and not the module, an
import writing an interface name and nothing else; a module exporting an
interface under another name is therefore reachable by `--import` and not by
the search path. A name the search does not find is not an error in itself —
§6.11.3 reports it as an interface nothing supplies, which is the diagnostic a
program that meant to pass `--import` wants. And the search path is bounded at
32 directories, reported rather than silently shortened, as every other bound
here is; a single directory longer than 4096 characters is refused for the
same reason.

**Resolution finds an interface and not an object.** `--dump-imports` writes
the components a translation read, one to a line in activation order, so the
program that assembles and links — `tools/pascalcc` here — can translate them.
That flag is the whole of the interface between the two halves, and it exists
so that nothing outside the compiler has to read Pascal to work the list out.

### 2.6 How a program terminates

Neither standard models a process exit status, so nothing here is required and
nothing is forbidden. What this processor does:

| Situation | Status |
|---|---|
| the program-block completes | 0 |
| §6.7.5.7's bare `halt` | 0 — 3.6 makes it normal termination, not an error |
| `halt(n)` — an extension, §5 | `n` |
| a run-time error (Annex D, a failed range check, a trap) | 1, with a message on standard error naming the position |

The message is one line, `runtime error: <message> at <file>:<line>:<column>`
(ADR-0293). `runtime error:` opens the line -- the harnesses here recognise a
trap by it -- and the position closes it, in the form this processor's
compile-time diagnostics use: the file as it was named to the compiler, and
the construct that trapped rather than the statement holding it, so the
subscript, the `to`-bound, the operator, the variable being read. A trap in a
separately translated component (§6.13) names that component's file. The
position is absent only where nothing supplied one: a trap raised by a
runtime routine the compiler did not bracket, of which none is known, and a
trap in a compiler built from the seed, until the seed is refreshed.

**A conforming program has no way to choose**, `halt` taking no parameter in
either standard and there being no other control procedure. `halt(n)` is this
processor's extension for exactly that reason — see §5, and ADR-0084 for why
the rule against inventing extensions does not reach a dimension neither
standard describes. It is what lets `pascalc` exit 1 for a program it
rejects, which a build rule depends on.

### 2.7 The dialect

Neither standard's Annex E asks any of these; they are questions
`doc/afterschool-pascal-spec.md` raises, and this is where it says the
processor states its answer. They are listed here rather than in that document
because a reader looking for what a processor decided should find every such
answer in one place, whichever document required it.

| Clause | Feature | This processor |
|---|---|---|
| AP 6.4.15.12 | the version of the Unicode Standard and of ISO/IEC 10646 determining Normalization Form C and the extent of an extended grapheme cluster | **Unicode 17.0.0** (2025-08-15). `pas_text_unicode_version()` reports it, `runtime/unicode/fetch.sh` pins it, and `runtime/pasrt_unicode_data.h` is generated from that version's database. |

**This is the one answer in this document that moves for a reason outside this
repository**, and AP 6.4.15.12's NOTE is why it has to be stated at all: which
code points make one element, and whether two values are equal, both change
with the version. A program entitled to depend on either is entitled to know
what it was compiled against.

Moving it is a decision and not an upgrade. `unicode-conformance` is what says
a move was clean — it runs the new version's own `NormalizationTest.txt` and
`GraphemeBreakTest.txt`, and it also refuses a version whose database does not
reproduce the committed tables.

## 3. Errors not reported

Clause 5.1 f) 1) permits an error to go unreported provided an accompanying
document says so, and requires the references to appear in a section of their
own. This is that section. Every entry is a rule of the standard that this
processor does not enforce.

Most were recorded in the architecture decision record that introduced the
feature, as they were decided. **Eight were not**, and were added when the list
was reconciled against Annex D — D.5, D.6, D.12, D.13, D.19, D.27, D.30 and
D.48. Each had been unenforced since the feature it belongs to landed, and this
document is where a reader looks instead of the source, so the omission was
worse here than anywhere else (ADR-0074). What found them is described below;
what let them sit is that the entries were written one feature at a time and
nothing had ever read the annex end to end against the compiler.

Most of them share one cause: the rule is a property of what happens while the
program runs, and deciding it would need the run time to carry information that
nothing in this implementation carries.

**How the ISO 7185 half of this list was checked.** Annex D restates that
standard's errors as fifty-nine numbered entries, and each was compiled and run
rather than read: the BSI Pascal Validation Suite's `ERROR` category has a
program for fifty-eight of them, each printing `ERROR NOT DETECTED` if it runs
to completion. Forty-three are reported by every program that names them,
fourteen by none, and D.4 by one of its two — see the note below. D.59 has no
program in that category; a probe that `reset`s a program-parameter bound to a
name which cannot be opened is reported, so it is a forty-fourth.

**That measurement cannot be repeated here, and the list below is therefore
asserted rather than regenerable.** The suite was the instrument and never the
claim -- running it was **not a validation**, on BSI's own conditions -- and
ADR-0232 retired it: its programs are conforming ISO 7185 and 25 use a
word-symbol ISO/IEC 10206:1991 §6.1.2 reserves, so this compiler cannot compile
the corpus. The numbers above stand as the finding they were, taken against a
compiler this one still contains; what is gone is the ability to take them
again. The ISO/IEC 10206:1991 entries have no such corpus and were
probed one clause at a time, as ADR-0073 describes.

**Two entries below stop these particular programs anyway, and that is not
detection.** An undefined pointer is often *nil* here — a level-0 activation
record is a global (ADR-0053) and so begins zeroed — and the nil checks on a
dereference and on `dispose` then fire. That reports D.4 and D.24 for the shape
where the variable was never assigned at all, and reports neither where the
pointer holds a stale address, which is the shape both errors are really about.
Nothing tracks definedness; a check that happens to coincide with one is not the
rule being enforced, and this is written down so that a green run of those two
programs is not mistaken for it.

**Real overflow is not on this list, and is not an omission.** §6.7.2.2 makes
the accuracy of the real operations implementation-defined rather than making a
result the type cannot represent an error, so `1e308 * 10.0` yielding an
infinity breaks no rule — see E.8 in §2 above, which is where that answer
belongs. The one real operation either standard *does* name this way is
`sqr` (D.32; D.57 in ISO/IEC 10206:1991, for both types in one sentence), and
it is checked (ADR-0078).

| Clause | The error, and where it is recorded |
|---|---|
| §6.6.5.3 / §6.7.5.3 (D.25) | A variable created by `new(p, c1, …, cn)` may not be an operand of an assignment nor an actual parameter, its unselected variants not existing. Detecting this needs the pointer's *value* to carry which form created it. ADR-0027. |
| §6.6.5.3 (D.19) | For `new(p, c1, …, cn)`, that no variant becomes active other than the ones named — assigning the tag activates whichever the value selects, and the store knows nothing of how the variable was created. Same cause as D.25. ADR-0027. |
| §6.5.4 (D.4) | Use-after-`dispose` through a *second* pointer to the same storage. `dispose` stores nil back into the variable it was given, which converts the common form into the nil trap, and does nothing for the general one. ADR-0019. |
| §6.5.4 (D.5) | Removing the identifying-value of a variable while a *reference to it* exists — `dispose(p)` from inside `with p^ do`, or while `p^` is bound to somebody's `var` parameter. What references exist is a run-time fact. The `with` form is lexically visible and the parameter form is not, and a check reporting one of the two would say the rule holds when it does not. ADR-0019. |
| §6.5.5 (D.6) | Altering a file-variable `f` while a reference to `f^` exists — a `put(f)` from inside `with f^ do`, or while `f^` is somebody's `var` parameter. Exactly D.5's shape, one type along. ADR-0021. |
| §6.5.3.3 (D.2) | Reading or writing a field of a variant that is not active. A constant's tag is a constant, so §6.8.8.3's version of this *is* reported (ADR-0069); the rule for a variable has never been checked. ADR-0018, ADR-0056. |
| §6.5.6 (D.16) | That the string-variable of a substring-variable is **defined**. §6.5.6's first error condition, and the one of its three that is not an index test: `var s: packed array [1..6] of char; writeln(s[2..4])` prints three spaces rather than reporting anything. The other two disjuncts *are* checked, and exactly — the emitted `lo < 1 or hi > len or hi < lo` is logically identical to D.16's over both index-expressions. Same cause as D.43 below, nothing here tracking definedness at run time; named separately because a reader auditing D.16 previously found §6.5.6 in this table for D.17 only and could conclude D.16 was enforced (ADR-0224). |
| §6.5.6 (D.17) | Altering the length of a string-variable while a reference to a substring of it exists. ADR-0057. |
| §6.6.3.8 | That the smallest and largest values of the index-type of T1 lie within the closed interval of T2, where T1 is itself a conformant-array-schema. Both bounds are then a run-time fact, arriving with that parameter's own actual; where T1 is an ordinary array-type the check is made at compile time and the program refused. BSI's LEV1F44 and LEV1F49 are the two programs that report *ERROR NOT DETECTED*. ADR-0153. |
| §6.7.5.5 | A write-parameter of `writestr` accessing the string-variable being written to. ADR-0060. |
| §6.7.3.2 | That the actuals of one parameter form naming the required schema `string` all have the same **length**. The clause makes each formal possess the type produced with "the tuple having that length as its component", so `procedure p(a, b: string)` with actuals of unequal length is an error — and the lengths are run-time values, unlike every other tuple in a parameter form, which is why the sibling check reported before the program ran and this one cannot. Both formals are given their own actual's length, which is the answer the clause would give if the lengths agreed and is a defined answer either way. |
| §6.11.3 | A constituent-identifier's defining-point is not enforced as a *region*. §6.11.3 a) gives it "each region that is a constituent-identifier contained by the import-specification" — a region as narrow as the occurrence itself — where this compiler makes the interface's names reachable across the import-specification while it is being checked. **No program distinguishes the two**, and every observable rule around it was probed: `only` imports exactly what it names, a renaming introduces the new spelling and not the old, the interface's own name of a renamed spelling is not imported, and NOTE 2's long-form-only rule holds. ADR-0053, ADR-0134. |
| §6.8.2 | Nonvarying is decided by what an expression can be *evaluated* to, not by what it may not *contain*. The two coincide for every expression an operator can build; where they did **not** coincide was a call, and the row used to claim "the same expressions are accepted", which was false — `succ(x,k)`, `pred(x,k)` and `length` were nonvarying by the clause and refused by this processor. Those three fold now, and so do the eight real-valued ones — `sqrt`, `sin`, `cos`, `ln`, `exp`, `arctan`, `trunc` and `round` — which this row sent to §6 as a **restriction** until ADR-0227 removed the cause instead. That entry is gone, so this row pointed at nothing for one commit. What §6 records now is the *accuracy* of a real-valued constant-expression, which NOTE 2 of this clause requires an implementation to state. Nothing §6.8.2 makes nonvarying is refused here. ADR-0054, ADR-0226, ADR-0227. |
| §6.6.5.2 (D.12) | That the buffer-variable is defined immediately before `put`. Two `put`s in a row is the error: the first leaves `f^` undefined, and nothing here records that. ADR-0021. |
| §6.6.5.2 (D.13) | That the file is defined immediately before `reset`. This processor prepares every file variable when its block is entered (ADR-0070), so the state the clause calls undefined does not arise: a `reset` of a file never given a name reads an empty scratch file rather than reporting anything. |
| §6.6.5.4 (D.27, D.30) | That no component `pack` or `unpack` accesses is undefined. `packed` means nothing to the layout here, so the transfer is a `memcpy` and there is no per-component read to attach a check to (ADR-0067) — and the definedness it would need is not carried in any case. |
| §6.7.3 (D.48) | That a function's result is defined when the activation completes. What is checked is *static*: a function body must contain at least one assignment to the result, or it is refused (ADR-0055). Whether the one it contains is on the path taken is the run-time half, and `if a > 0 then x := … else area := 0` returns whatever the slot held. |
| §6.6.5.3 (D.20–D.22) | That `dispose(p)` matches the `new` that created the variable, and that `dispose(p, k1, …, km)` names the same variants with the same count. Same cause as D.25 above: it needs the pointer's *value* to carry which form created it. `dispose` of nil **is** reported (D.23) — that one needs nothing carried. ADR-0027, ADR-0077. |
| §6.7.1 (D.43), §6.6.5.3 (D.24) | Using a variable that is undefined — in an expression, or as `dispose`'s argument. **Nothing here tracks definedness at run time**, which is the cause D.4, D.12, D.13, D.27, D.30 and D.48 above each share rather than an entry of its own; Annex D names it in thirteen of its fifty-nine entries. **Five** of those ask whether a *file* is defined — D.10, D.15, D.40, D.41 and D.57 — and the runtime does carry a file's mode, so those five are reported. The other **eight** are D.4, D.12, D.13, D.24, D.27, D.30, D.43 and D.48, and none of them is enforced; two of the eight nonetheless stop the suite's own program, for the reason given above the table. ADR-0077. |

## 4. Implementation-dependent features

ISO 7185 Annex F lists ten and ISO/IEC 10206:1991 Annex F eighteen. Fifteen of
the eighteen ask the same question about a different construct — in what order
are things evaluated — and this processor answers all of them the same way:

> **Written order, left to right**, with a variable-access completed before the
> value that will be stored into it, and a structured-value-constructor's
> completer before its written components.

That order is the same in both compilers — the C++ one and the Pascal-hosted
one of `selfhost/` — and the same at `-O0` and at `-O2`. It can only be
*observed* where the sub-expressions have side effects; where they are pure the
optimiser may reorder freely, which no program can detect.

**One departure is worth stating separately, because it is stronger than an
order.** §6.8.3.1's dyadic operators include `and` and `or`, and those
**short-circuit**: the right operand may not be evaluated at all. ISO 7185
§6.8.3.3 permits this and ADR-0010 chose it. `and then` and `or else` are
excluded from the clause because they *require* it.

| 10206 | 7185 | Question | This processor |
|---|---|---|---|
| F.1 | — | order of a block's discriminant-values on activation | Variables in declaration order; within one variable, discriminants left to right. Observable only in a procedure or function block — at the outermost block a function identifier is not in scope inside the variable-declaration-part, so no such discriminant can have a side effect. |
| F.2 | F.2 | indexed-variable: index-expressions and the access | The array or string variable is accessed first — its address computed and its nil check made — then the index-expressions left to right. `p^[e(1)]` with `p = nil` traps without evaluating `e`. |
| F.3 | — | substring-variable | Variable accessed, then the lower bound, then the upper. |
| F.4 | — | `new(p, d1, …, ds)` | Left to right. |
| F.5 | F.3 | expressions of a member-designator | Lower bound, then upper. |
| F.6 | F.4 | member-designators of a set-constructor | Left to right. |
| F.7 | F.5 | operands of a dyadic operator | Left, then right — **except that `and` and `or` short-circuit**, so the right operand may not be evaluated. Both operands of an arithmetic operator are evaluated before its overflow check. |
| F.8 | F.6 | actual-parameters of a function-designator | Written order, left to right. Evaluating a value parameter, computing a `var` parameter's address, and copying a structured value parameter each happen at that parameter's own position; a value parameter's copy is taken at binding, before the body runs. |
| F.9 | — | indexed-function-access | The call is evaluated in full — arguments, then body — and only then the index-expressions. |
| F.10 | — | substring-function-access | Call, then lower bound, then upper. |
| F.11 | — | component-values of a structured-value-constructor | The completer (`otherwise`) first, then the written component-values in **written** order — not field or index order. A component-value serving a range of components is evaluated once. |
| F.12 | — | index-expressions of an indexed-constant | Left to right, in both the `c[i][j]` and `c[i, j]` spellings. |
| F.13 | — | index-expressions of a substring-constant | Lower bound, then upper. |
| F.14 | F.7 | assignment: accessing the variable and evaluating the expression | The **variable first**, including every check on that access. `a[99] := e` reports the bounds error without evaluating `e`. |
| F.15 | F.8 | actual-parameters of a procedure-statement | As F.8. |
| F.16 | — | order of selection in `for v in s` | Ascending ordinal order of the base type. An empty set runs the body no times. |
| F.17 | — | whether a numeric read examines the buffer-variable or the first component of `f.R` | The **first component of `f.R`**: the buffer-variable's value is ignored. A store into `f^` before `read(f, i)` is visible when `f^` is read back and has no effect on the number read. |
| F.18 | F.9 | inspecting a text file `page` was applied to | `page(f)` writes an implicit line terminator when the line is non-empty, then `chr(12)`. On inspection that character is an ordinary component at the start of the next line, and `eoln` and `eof` behave as for any other file. |
| — | F.1 | attributing a character prohibited from textfiles | The prohibited set is exactly `chr(10)`, and attributing it ends the line: the character is not stored, `eoln` becomes true where it was written, and the line reads back one component shorter. Every other value of `char` — all 256 — survives a line unchanged. `tests/textfile_chars.pas`. |
| — | F.10 | binding of a **non-file** program parameter | **Bound to nothing.** It is an ordinary variable of the program block, totally-undefined until the program assigns it, and it consumes no command-line argument — so the file parameters keep the argument positions they would have had without it. ISO/IEC 10206:1991 §6.12 NOTE 2 ("variables that are program-parameters are not necessarily bound when the program is activated") is what makes that an available answer rather than an omission. `tests/progparam_nonfile.pas`. |

## 5. Extensions

Clause 5.1 g) requires extensions to be described as *extensions to Pascal as
specified by ISO/IEC 7185*. There are four.

**`halt` takes an optional integer argument, the exit status**, where
§6.7.5.7 gives it no parameters. `halt` alone exits 0, as it always did;
`halt(n)` exits with `n`. Neither standard models a process exit status at all,
so there was no spelling to take from either — and without one a Pascal program
cannot tell whatever invoked it that it failed, which a compiler written in
Pascal has to be able to do. No conforming program's meaning changes: `halt(1)`
was a compile-time error until this landed, so no valid program contains it, and
every path that reached `halt` before still exits 0. ADR-0084;
`tests/extended/halt_status.pas`.

**`BindingType` has a third field, `writable`**, which ISO/IEC 10206:1991
§6.4.3.4 NOTE 7 permits in as many words: *"A processor may provide additional
fields as an extension."* Where the file-variable is bound to an external
entity, it is true if and only if the entity could be opened for writing when
`binding` was applied; where it is bound to nothing, it is false. It is an
extension to ISO 7185 outright, that standard having no binding at all.

It exists because the read side of an open has a question and the write side
had none. §6.7.5.6's NOTE 2 offers `binding(f).bound` as the test of a binding,
and E.16 above makes it *the entity exists* — which is what a program about to
`reset` wants. A program about to `rewrite` wants the opposite question and
there was no way to ask it: §6.7.5.2 leaves the activities on the external
entity implementation-defined (E.15), this processor's choice on a failure to
create is to terminate the program, and no conforming program could find out
first. The four writers of `lib/pasfile.pas` were procedures that could not
report and did fail, and `lsp/pasls.pas` could be killed by a bad
`PASLS_SCRATCH` however carefully it was written.

No conforming program's meaning changes: a field-identifier of a required
record-type is not a name a program can otherwise use in that position, and
`binding` returns the whole record whether or not a program reads the field.
Like `bound`, it reports a moment and promises nothing about the next
statement. AP 6.4.3.4.7, ADR-0240; `tests/dialect/binding_writable.pas`.

**A discriminated-schema may be written where a parameter-form or a
result-type requires a name.** §6.7.3.1 gives a parameter-form as
`type-name | schema-name | type-inquiry` and §6.7.2 gives
`result-type = type-name`, so `procedure q(x: string)` names a schema and is
inside the grammar, while `procedure q(x: string(5))` and
`function f: string(5)` write a schema *production* where a name is required
and are outside it. This compiler accepts both, and always has.

What it denotes is the type that schema and that tuple produce, so every rule
this language states over types answers here unchanged: a variable parameter
requires the actual to possess that very type, congruity compares the types two
parameter-forms denote, and `Cap5 = string(5)` and `string(5)` are
interchangeable. The addition is one alternative and not a relaxation — a
parameter's type is still not a type-denoter, and an inline record, array, set,
subrange, enumeration or pointer denoter is refused in both positions. A
type-inquiry remains admissible in a parameter-form and inadmissible in a
result-type.

No conforming program's meaning changes: a discriminated-schema is outside the
production it is added to, so no conforming program can contain one there. It
is an extension to ISO 7185 outright, that standard having no schemata at all.
It was accepted before it was decided — ADR-0171 found it and left it as an
acceptance no clause stated, and ADR-0232 removed the conformance mode that
could have refused it. AP 6.7.3.1.1 and AP 6.7.2.1, ADR-0324;
`tests/dialect/discriminated_form.pas`.

**An identifier may contain an underscore**, where §6.1.3 makes an identifier
`letter { letter | digit }`. It is how this project spells a name that would
otherwise collide with a word-symbol — `label_`, `set_`, `packed_` — and how a
test program takes the name of its file. No program's meaning depends on it:
an underscore can begin no other token, so a program without one compiles
identically. ADR-0072.

## 6. Restrictions

These are the other direction: programs the standard admits and this processor
refuses. Clause 5.1 c) does not permit them, so each is a known deviation and
none is silent.

**A file may not be a field of a variant part**, which ISO 7185 §6.4.3.3 and
ISO/IEC 10206:1991 §6.4.3.4 — one clause under two numbers — both permit. A
file's storage carries a heap buffer and a place on the runtime's open-file
list, so two arms holding files at one address would leak the first buffer and
link one list node twice (ADR-0070).

**`bind`, `unbind` and `binding` are refused for a variable that is not a
file, and that is a design since AP 6.5.1 (ADR-0299).** ISO/IEC 10206:1991
§6.7.5.6 makes the file case the *conditional* one and the other case
unconditional: "If the variable-access f possesses a file-type, it shall be a
dynamic-violation if the variable does not possess the bindability that is
bindable; **otherwise, the variable shall possess the bindability that is
bindable**" — the same sentence in `unbind`, and §6.7.6.8 for `binding`. So
`var i: bindable integer` may be bound under the standard, and here
`bind(i, b)` is refused with *'bind' needs a file variable, found integer:
only a file variable is bindable*.

Nothing is lost silently: the declaration is accepted and §6.9.3.9.1's
nonbindable rule is enforced against it (ADR-0170), so the bindability of a
non-file variable is a real property that only the three procedures decline to
act on. What binding such a variable would *mean* is implementation-defined
and AP 6.5.1's second paragraph declines to define it, which is the one
restriction that clause states; until ADR-0299 this entry called it a
restriction rather than a design because no record had decided it. The other
half of the same clause — every *file* variable is bindable, the word or not —
is an acceptance rather than a restriction and is in §6.1 below.

Found by ADR-0167's third reader and carried in `doc/roadmap.md` until
ADR-0299, as a design owed rather than a bug. What was missing for a long time
was this entry: a restriction §5.1 c) does not permit belongs in **this** list
whether or not it is also on a work queue, and reaching it a second time while
probing ADR-0170 is what showed that §6 could not be searched for it.

**The accuracy of a real-valued constant-expression is the accuracy of the
same operation at run time.** ISO/IEC 10206:1991 §6.8.2 NOTE 2 requires this
sentence of every implementation — "since the accuracy of mathematical results
of the real-type and of the complex-type are implementation-defined (see
6.4.2.2), an implementation is required to specify the accuracy of
constant-expressions" — and until ADR-0227 the answer given here was *there are
none*: eight required functions and every real-valued operator were refused.

They fold now, and the specification is the one sentence above. It is exact
rather than approximate, and the mechanism is why. A real constant is still the
text that was written (ADR-0025); a fold reads that text with §6.10.4's
`readstr`, computes with **this compiler's own arithmetic**, and writes the
result back with `writestr` at a total-width of 30 — 24 significant digits,
where 17 name a binary64 uniquely. So `**` and `pow` reach `pas_pow_real` and
`pas_pow_realint`, and `sqrt`, `sin`, `cos`, `ln`, `exp` and `arctan` reach the
same library the emitted code calls: a constant-expression is not a second
implementation of arithmetic, free to round differently from the first.
`tests/extended/constexpr_reals.pas` asserts the six mathematical functions
that way — the folded constant equals the run-time value — rather than by
writing their digits down, because the digits would pin this machine's library
and not the language.

Two consequences are worth stating plainly. The four arithmetic operators,
`abs`, `sqr`, the comparisons and the two conversions are exact under IEEE 754,
so a folded result of those is the same value on any conforming processor. The
six mathematical functions are correctly rounded by no standard, so
**cross-compiling to a target whose library differs from the host's may give a
folded constant a different value from the same expression evaluated at run
time on that target.** That is the latitude §6.4.2.2 leaves, and the reason
NOTE 2 asks for this paragraph at all. And an error the clause names — a zero
divisor, `ln` of a value that is not positive, `sqrt` of a negative one, a
negative base of `**`, a zero base raised to a non-positive power, `trunc` or
`round` out of integer range, and overflow — is a **compile-time diagnostic**
where a constant-expression commits it, because the fold has to ask before it
operates.

**That entry has now been wrong twice and struck twice.** It read "nine" until
ADR-0226, the ninth being `substr`, and the reason recorded for it — "its
result is a string, which has no scalar form to fold to" — was never true: a
string constant *is* a literal, named (ADR-0068), which is what the
substring-constant fold builds. ADR-0224's audit found that entry wrong in
three ways at once (it named `substr` alone where concatenation, `trim` and the
string relationals were refused too; the relational yields a *boolean*, which
the reason could not cover; and the folder demonstrably produced a string
constant one level down, inside a structured-value-constructor). It then read
"eight", and the reason recorded for those was true as a fact about this
compiler and false as a restriction §5.1 c) permits — so ADR-0227 removed the
cause rather than documenting it better. Both halves fold now, in both front
ends.

**A set-valued constant-expression is still refused**, and that half of the old
sentence was true: the folder builds no set node, so there is nothing for the
result to be. `const s = [1] + [2]` is refused with *the value of constant 's'
is not a compile-time constant*, which is the generic message and not one that
says which — the same complaint ADR-0224 made about the string forms, still
standing for this one.

**A subrange whose bounds are not constants is refused as a set's base type.**
`set of 1..m` inside a procedure is legal under §6.2.3.8 b) and is refused with
*the bounds of a subrange must be ordinal constants*. Every set here is one
256-bit word whose base type must have its values in 0..255 (ADR-0028), and a
bound the block evaluates cannot be checked against that before the program
runs — so it is the limit `set of integer` already states, reached by a
different route.

Everything else is **fixed**, and it took five records to get there.
`var v: vector(m)` has always worked; `var a: array [1..m] of real` works since
ADR-0113; `type t = vector(m)` and `type t = array [1..m] of real` since
ADR-0127; the bare subrange as a variable's type, a type-definition and an
array's component since ADR-0133; and as a **record's field** and a **file's
component** since ADR-0134 — a record being no kind of block, so a bound
written inside one is still closest-contained by the block the declaration is
in. ISO 7185 §6.4.2.4 wrote `subrange-type = constant '..' constant`, so none
of this was available there; ISO/IEC 10206:1991 §6.4.2.4 writes
`subrange-bound = expression`, and that is the reading this language takes. The
type-definition
half was the finding of the second independent reading most likely to break a
real program (ADR-0107).

What a record and a file refuse is the *consequence* rather than the position:
a field or a component whose **size** the bound decides, because a field's
storage is laid out where the record is and a file is told one component size
when it is prepared. `record f: array [1..m] of integer end` is that, and it is
a refusal rather than a deviation — the standard's own §6.2.3.8 b) evaluates
the bound, and ADR-0045's rule about where a dynamically sized part may sit is
what has no answer for it. Admitting it unchecked was measured: `v.a[1]` read
99140726979296144 where 1 had been stored.

**An identifier or a character-string longer than 255 characters is
refused.** §6.1.3 makes every character of an identifier significant and
§6.1.7 puts no bound on a character-string, so both limits are this
processor's. Each is *reported*: `identifier is too long: this compiler keeps
255 characters and every one of them is significant`, and `string literal is
too long: this compiler keeps 255 characters`.

Until a security audit found it they were applied by silent truncation
instead, which is a worse thing than a limit. Two identifiers agreeing in
their first 255 characters became one name, so a program could assign to one
and read the other with nothing said; and `writeln` of a 300-character literal
printed 255 of them, so a program's output did not match its source.
`selfhost/badparse/ident_too_long.pas` and `string_too_long.pas` pin both.

**A statement whose string values need more than 1 048 576 characters at once
is refused**, at run time, with *more string values are live at once than the
string arena holds*. ISO/IEC 10206:1991 §6.8.3.6 puts no bound on the length of
a concatenation, so the number is this processor's. Only what a *statement*
holds counts: the storage is given back when the statement finishes, so a loop
may concatenate without limit, and `tests/extended/str_arena_loop.pas` passes
four megabytes through the arena. A single value larger than the whole arena is
reported separately, as *a single string value is larger than the string
arena*.

Until ADR-0111 the storage was a ring and this was the second limit ADR-0110
found applied in silence — the wrap wrote one value over another, so
`a + a = b + b` over two 512K strings reported two values differing in every
character as equal, and exited 0.
`tests/extended/str_arena_overflow.pas` is that program.

**A program needing more than 1 000 000 characters of identifier and literal
text, or more than 300 000 tokens, is refused.** Neither standard bounds the
size of a program, so both numbers are this processor's; each is *reported*, as
`out of string space: this compiler keeps 1000000 characters of text` and `too
many tokens: this compiler accepts 300000`. `pascalc --dump-limits` writes how
much of each a compilation used, so the limits can be read off a real program
rather than guessed at (ADR-0148):

```
pool 558579 of 1000000
tokens 190765 of 300000
comments 1423 of 20000
```

Those figures are this compiler's own source, which is the largest Pascal in
this repository. One way into the pool does *not* report: `PoolPut`, which
builds the two names Sema needs rather than reads, drops a character instead of
diagnosing when the pool is full. It is reachable only once the pool is within
a name's length of full and is registered in `doc/sop.md` §7.

**The third bound is not a limit on a program** (ADR-0279). §6.1.8's comments
are recorded, rather than discarded, only when `--format`, `--dump-trivia` or
`--dump-limits` asks for them, so an ordinary compilation has no such table
and cannot fail for want of one. A source with more than 20 000 comments
compiles exactly as it did; what is refused is the *request*, as
`this source has more than 20000 comments, which is more than --format can
keep in order` — because a file printed with a comment silently missing from
it would be worse than no answer at all.

**Nesting deeper than 1000 levels is refused** (ADR-0020) —
parentheses, statements, type denoters, blocks, or the depth of the tree an
operator chain builds. The bound is on the *tree* rather than on the parser's
own recursion, because a long `a+b+c+…` chain parses iteratively and is deep
only for the walkers after it. A program's own block is one of the levels, so
999 remain inside it. Blocks began to count only after the same audit found
1001 nested procedures indexing Sema's scope stack off its end.

**A type may need at most `maxint64` bytes of storage, and an array's index
type may span at most `maxint` values.** Two bounds and they count different
things — the second is a distance between two index values and the first a
number of bytes — so a type can pass either and fail the other.
`array [-1..maxint] of char` spans one value too many and is refused for the
count; two nested `array [1..maxint]` of a four-byte element is 1.8e19 bytes
and is refused for the storage.

The element bound is the older one and is not arbitrary: `verify/`'s
`accepted-index-selects-the-right-element` rule proves that an accepted
subscript selects the right element, and its precondition is that `i - lo` is a
value of the integer type. That is why the bound is a **span** and not a count:
`hi - lo` must be a value of `-maxint..maxint`, so the largest array is
`maxint + 1` components and `array [0..maxint] of char` — 2 GB, and how a
program spells an index as wide as one goes — is the last legal one rather
than the first illegal one. It was refused until ADR-0289, on a ground no
clause supplies: a refusal at that size is defensible only as a capacity, and
this processor accepts a larger record. The storage bound is what the compiler
can lay out (ADR-0287). Both are reported where the type is written, with a
position, and neither had an entry here until ADR-0287 — the element bound had
been enforced since the conformance sweeps and documented nowhere a user would
look, which is most of why it went eleven increments without anyone comparing
it against the record beside it.

**What is *not* bounded here is what the machine can hold.** A global variable
above about 2 GB is refused by the linker's small code model — `relocation
truncated to fit`, a message from `ld` naming no source line — and a heap
object by the memory available. Neither is a fact this processor could state
for every target `--target=` admits, so neither is stated. A type between 2 GB
and `maxint64` is accepted and works on the heap, which is now the only place
an array at the element bound can live: `tests/index_span.pas` allocates one,
indexes both ends and disposes it.

### 6.1 Programs accepted that the standard requires to be rejected

The first three above are deviations this project chose, and the last three are
limits it states rather than hides. These are the other kind: rules of ISO 7185 that a program can
break without this compiler saying so.
They were found the way the unreported errors in §3 were — by the BSI Pascal
Validation Suite's `DEVIANCE` category, whose programs a conforming processor
must refuse or stop — and, as there, **no program written here had ever
exercised one**, so every oracle in the repository agreed the compiler was
right. The suite is gone (ADR-0232) and this list is now maintained here,
by hand, which is worth knowing before trusting its completeness: what found
these entries can no longer be re-run.

**One was known here until ADR-0299, and it is now the rule.**
ISO/IEC 10206:1991 §6.7.5.6 and §6.7.6.8 require the variable-access given to
`bind`, `unbind` and `binding` to possess the bindability that is bindable,
and this compiler did not ask that of a **dereference**: `bind(p^, b)`
compiled whatever the domain-type denoted — right for `p: ^bindable text`,
which §6.4.4 permits, and wrong for `p: ^text`, a program the clause requires
to be rejected. Found by reading (ADR-0167's third reader) rather than by the
suite, which was ISO 7185 only and had no binding at all; carried here from
ADR-0170, which fixed the field and the component and not the pointer, whose
domain reaches Sema through `ResolvePointer`'s deferred paths where the denoter
that knew is out of hand.

AP 6.5.1 makes **every file variable bindable**, so the program is accepted by
decision and this list has no entry for it: `bind(p^, b)` for `p: ^text`, a
`var f: text` formal bound inside its body — §6.7.6.8's own example — a
`text` field and a `text` element are all programs of this dialect, and the
word `bindable` on a file is accepted and redundant. Every conforming program
keeps its meaning (AP 6.0.1); what moved is only that a refusal the standard
requires is not made. `tests/dialect/bind_anywhere.pas` is the program and
ADR-0299 the record.

**The rest is empty**, and the emptiness is a claim about what is
*known* rather than a proof. The BSI suite's `DEVIANCE` category has no program
left that this compiler accepts — every one of them is refused, and the single
exception stops at run time, which §5.1 permits — and that is the strongest
statement available here, the catalogue being a fixed corpus of 812 programs
from 1982 rather than something that grew with the language.

The last entry was **§6.4.3.3's record region at a *constant* occurrence**, and
it was found by reading rather than by the suite (ADR-0101). §6.4.3.3 gives a
field-identifier its defining-point in the record-type closest-containing the
field-list and §6.2.2.4 makes the scope the whole of that region, so in

```pascal
const fred = 3;
type r = record a: array [1..fred] of integer; fred: integer end;
```

the bound `fred` is the field and names no constant. ADR-0112 had enforced that
at every occurrence of a *type-name* — a field's own denoter, an array's
index-type and component-type, a set's base-type, a file's component-type, a
pointer's domain-type and a schema-name — and a constant occurrence goes
through the expression checker instead, which is why it was the one left.
ADR-0134 asks there too.

Before ADR-0112 the entry was larger still: only `^fred` was refused, while
`record a: fred; fred: integer end`, an array whose index-type names a field,
and a field named `integer` taking that spelling from the required identifiers
were all accepted. Same clause, same region; only the occurrence differed.

