# Implementation-defined and implementation-dependent behaviour

This is the document ISO/IEC 7185:1990 clause 5.1 d) and ISO/IEC 10206:1991
clause 5.1 d) and j) require a complying processor to be accompanied by. It
states the compliance level, defines every implementation-defined feature,
describes the treatment of every implementation-dependent one, names each error
this processor does not report, and describes the extensions it accepts.

Both standards list their own features again in informative annexes, and the
tables below follow that numbering so an entry can be found from the standard
rather than from this document's own headings. Where the two standards ask the
same question, the answer is given once and both entry numbers are cited.

Behaviour is the same under `--std=iso7185` and `--std=extended` unless an
entry says otherwise.

## 1. Compliance level

**This processor complies at level 0.** ISO 7185 clause 5.1 a) defines level 0
as accepting every feature of clause 6 except §6.6.3.6 e), §6.6.3.7 and
§6.6.3.8 — the conformant array parameters. Those are not accepted:

```pascal
procedure sum(a: array [lo..hi: integer] of integer);
```

is refused with *a parameter's type must be a type name*, §6.7.3.1's
`parameter-form` being a type-name, a schema-name or a type-inquiry here. A
schematic formal parameter (ADR-0040) covers the same ground in Extended
Pascal — `procedure p(var v: vector)` takes a vector of any length, and one
compiled body serves every tuple — but it is a different feature of a different
standard and does not make this a level 1 processor.

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
| E.4 | E.3 | the real-type | IEEE 754 binary64. |
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

### 2.3 Output

| 10206 | 7185 | Feature | This processor |
|---|---|---|---|
| E.24 | E.10 | default TotalWidth for integer | The exact number of characters the value needs — its digits, preceded by `-` when negative. Nothing is padded. |
| E.25 | E.11 | default TotalWidth for real | ExpDigits + 17: nineteen characters, or twenty when the exponent needs three digits. DecPlaces follows §6.10.3.4.1's `ActWidth − ExpDigits − 5`, giving twelve fractional digits. |
| E.26 | E.12 | default TotalWidth for Boolean | The length of the word written — 4 for `TRUE`, 5 for `FALSE`. Nothing is padded. |
| E.27 | E.13 | ExpDigits | **2, except that an exponent of magnitude 100 or more is written with 3.** §6.10.3.4.1 reads as though ExpDigits were a fixed number; it is not here, because C's `%E` writes as many digits as the exponent needs. Stated as a deviation in ADR-0064. |
| E.28 | E.14 | the exponent character | `E`, upper case, always. |
| E.29 | E.15 | the case of `True` and `False` | Every letter upper case: `TRUE` and `FALSE`. With an explicit width the value is padded on the left and truncated from the left; at width 0 nothing is written. |
| E.30 | E.16 | the effect of `page(f)` | Writes `chr(12)`, preceded by an implicit `writeln(f)` when the current line is not empty (§6.9.5's own rule). Refused at compile time for any file that is not a `text`. |

### 2.4 Files and binding

| 10206 | 7185 | Feature | This processor |
|---|---|---|---|
| E.15 | E.7 | when file operations are actually performed | At the call, through C stdio; `reset`, `rewrite` and `extend` open or reopen the stream, `get` and `put` transfer one component. One component of lookahead is held (ADR-0021), so the stream is one component ahead of the program. |
| E.14 | — | the variable-string-type of `BindingType.name` | `string(255)`. |
| E.16 | — | what `bind(f, b)` binds to | The file whose pathname is `b.name`, with trailing spaces trimmed; the file is thereafter an external one, as a program parameter is (ADR-0052). |
| E.19 | — | the value `binding(f)` returns | `name` is the pathname the file is bound to, or the null string for an internal file; `bound` says whether it is bound. |
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

## 3. Errors not reported

Clause 5.1 f) 1) permits an error to go unreported provided an accompanying
document says so, and requires the references to appear in a section of their
own. This is that section. Every entry is a rule of the standard that this
processor does not enforce; each is recorded in the architecture decision record
that introduced the feature, and none was omitted silently.

Most of them share one cause: the rule is a property of what happens while the
program runs, and deciding it would need the run time to carry information that
nothing in this implementation carries.

**Real overflow is not on this list, and is not an omission.** §6.7.2.2 makes
the accuracy of the real operations implementation-defined rather than making a
result the type cannot represent an error, so `1e308 * 10.0` yielding an
infinity breaks no rule — see E.8 in §2 above, which is where that answer
belongs. The one real operation either standard *does* name this way is
`sqr` (D.32; D.57 in ISO/IEC 10206:1991, for both types in one sentence), and
it is checked (ADR-0078).

| Clause | The error, and where it is recorded |
|---|---|
| §6.6.5.3 / §6.7.5.3 | A variable created by `new(p, c1, …, cn)` may not be an operand of an assignment nor an actual parameter, its unselected variants not existing. Detecting this needs the pointer's *value* to carry which form created it. ADR-0027. |
| §6.5.4 | Use-after-`dispose` through a *second* pointer to the same storage. `dispose` stores nil back into the variable it was given, which converts the common form into the nil trap, and does nothing for the general one. ADR-0019. |
| §6.5.3.3 | Reading or writing a field of a variant that is not active. A constant's tag is a constant, so §6.8.8.3's version of this *is* reported (ADR-0069); the rule for a variable has never been checked. ADR-0018, ADR-0056. |
| §6.5.6 | Altering the length of a string-variable while a reference to a substring of it exists. ADR-0057. |
| §6.7.5.5 | A write-parameter of `writestr` accessing the string-variable being written to. ADR-0060. |
| §6.4.3.6 | `length(f) > ord(b) - ord(a) + 1` for a direct-access `file [a..b] of T` — an eleventh component written to a `file [1..10]`. Enforcing it is a check per component written. ADR-0050. |
| §6.7.2 | A function with a result-variable-specification that never *threatens* the result. Only assignment is required here, and §6.9.4's *threatens* is weaker — a `read` into it counts. ADR-0055. |
| §6.8.2.2 | That an assignment's function-identifier is the containing block's, so a sibling function's is refused. ADR-0055. |
| §6.9.4 g) | A `for` statement's body assigning to the control variable, in either the sequence or the set-member form. ADR-0063. |
| §6.4.9 | That a type-inquiry's parameter-identifier object is in the closest-containing formal-parameter-list. Ordinary lookup also sees the enclosing list. ADR-0047. |
| §6.11.3 | Where a `qualified` import's names may be written, outside the import-specification itself. ADR-0053. |
| §6.8.2 | Nonvarying is decided by what an expression can be *evaluated* to, not by what it may not *contain*. The same expressions are accepted; a few are rejected for a different reason and with a different message. ADR-0054. |
| §6.6.5.3 (D.20–D.22) | That `dispose(p)` matches the `new` that created the variable, and that `dispose(p, k1, …, km)` names the same variants with the same count. Same cause as D.25 above: it needs the pointer's *value* to carry which form created it. `dispose` of nil **is** reported (D.23) — that one needs nothing carried. ADR-0027, ADR-0077. |
| §6.7.1 (D.43), §6.5.4 (D.4), §6.6.5.3 (D.24) | Using a variable that is undefined — in an expression, as the pointer of an identified-variable, or as `dispose`'s argument. Nothing here tracks definedness at run time, so this is the cause the entries above keep sharing rather than an entry of its own; it is written down because Annex D names it three times and a reader should not have to infer it. ADR-0077. |

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
specified by ISO/IEC 7185*. There is one.

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

**Set compatibility ignores packing**, which is the one entry that goes the
*permissive* way and so belongs here only for being read beside the rest.
§6.4.5 c) makes two set-types compatible only if both are `packed` or neither
is, and only the base types are compared here — see ADR-0072 for why that is
deliberate.

**Program-components are not compiled separately.** §6.13 asks for it with a
*should* rather than a *shall*; accepting them apart would need an interface
artefact this compiler does not define (ADR-0053).

**A file may not be a field of a variant part**, which §6.4.3.4 permits. A
file's storage carries a heap buffer and a place on the runtime's open-file
list, so two arms holding files at one address would leak the first buffer and
link one list node twice (ADR-0070).

**Conformant array parameters are not accepted**, which is what makes this a
level 0 processor rather than a deviation — see §1.
