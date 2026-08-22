# ADR-0171: The fourth audit's last seven, and a refusal that was a lowering

Date: 2026-08-23

## Status

Accepted. Closes the list ADR-0168 left. That record adjudicated two of the
fourth `.claude/skills/langspec-audit/` run's findings before the v2.0.0 tag,
ADR-0169 took two more and ADR-0170 three; these are the remainder.

## Context

ADR-0168's closing list was written "verbatim from the reports, unverified",
and its own instruction was that each needed step 7 — the probe reproduced and
the clause re-read — before being believed. Seven were left. All seven were
probed against the compiler and read against ISO/IEC 10206:1991; four were
defects and are fixed here, two were readings this compiler already had right,
and one was a sentence in this repository's own documentation that named the
wrong end of a string.

Two of the four had the same shape, and it is worth naming because it is not
the shape an audit expects to find. **The compiler was refusing a program for
a reason about its own lowering, written down as though it were a rule.** In
one case the diagnostic said so in as many words — *a value parameter is
copied rather than padded; so the argument must have the same length* — which
is a true sentence about how this compiler passes an argument and no sentence
at all about Extended Pascal. In the other, nothing was said: a required
function had no arm in the constant folder, so the standard's own example of a
constant-definition-part did not compile and the message was that the constant
was not constant.

## Decision

### 1. A value parameter of a string-type takes any assignment-compatible actual (§6.7.3.2)

§6.7.3.2 is explicit about what the actual has to satisfy:

> If the parameter-form of the value-parameter-specification contains a
> type-name or a type-inquiry, each formal-parameter associated with an
> identifier in the identifier-list in that value-parameter-specification
> shall possess the type denoted by the type-name or type-inquiry,
> respectively. The value in the underlying-type of the type of each
> corresponding actual-parameter, associated with the value of the
> actual-parameter (see 6.4.2.5), shall be **assignment-compatible** with the
> type possessed by the formal-parameters.

Assignment-compatible, not equal. §6.4.5 d) makes every string-type compatible
with every other, §6.4.6 f) makes a value assignment-compatible with a
string-type of at least its length, and §6.4.6's last paragraph says what that
means:

> At any place where the rule of assignment-compatibility is used to require a
> value of the canonical-string-type to be assignment-compatible with a
> fixed-string-type or the char-type, the canonical-string-type value shall be
> treated as a value of the fixed-string-type whose components in order of
> increasing index shall be the components of the canonical-string-type value
> in order of increasing index **followed by zero or more spaces**.

§6.4.3.3.1's NOTE draws the conclusion without leaving it to be derived:
"String-type values may be used as the actual-parameter corresponding to a
value parameter possessing a string-type (see 6.7.3.2)."

So `show('abc')` for `procedure show(s: packed array [1..5] of char)` is a
legal program and `s` is `'abc  '`. This compiler refused it, and had refused
it since the fixed-string formal existed. The assignment `f := 'abc'` had
padded correctly the whole time, which is what makes the refusal a defect
rather than a gap: one rule, two answers.

**What was actually missing was storage.** A structured value parameter travels
as an address (ADR-0017) and an actual of a different length has none of the
formal's shape, so the padded value has to be built somewhere and there was
nowhere. ADR-0052's note that there was nowhere was true when it was written
and stopped being true at ADR-0115, which gave a *variable*-string value
parameter the same conversion — in the callee's prologue, because there the
capacity is the callee's. Here it is the caller's, because the formal's
capacity is written in the formal, so the conversion happens at the call and
what travels is the address of the converted value.

The storage is the **string arena** (ADR-0111), whose lifetime is exactly
wanted: longer than the argument list, no longer than the statement. An
`alloca` could not have served — a call inside a loop would claim one on every
iteration (ADR-0102) — and being a new arena producer it bumps ADR-0111's
counter, which nothing checks (`doc/sop.md` §7 carries that row already).

`PadsToFixedString` is the predicate, asked by Sema and by CodeGen, and it is
deliberately narrow: an actual that is already a char array of the formal's own
length answers **false** and is copied from its own address as before. Nothing
that compiled before this change is lowered differently.

§6.4.6 c)'s over-long value stays an error reported at run time, by the same
`pas_str_fits` an assignment reaches, because the actual's length is not always
known at compile time.

### 2. `value` in a parameter position is refused, and correctly (§6.7.3.1)

The reader reported an initial-state-specifier after a discriminated-schema in
a parameter position as a possible gap. It is not. §6.7.3.1's production has
three alternatives and no bracket:

> parameter-form = type-name | schema-name | type-inquiry .

A type-denoter may carry an initial-state-specifier (§6.4.1); a parameter-form
is not a type-denoter and cannot. The refusal is right and is **CONFIRMED**.

Probing it turned up something else, which is recorded here and **not fixed**.
That same production does not admit a *discriminated-schema* either — only a
bare `schema-name` — so `procedure q(x: string(5))` is outside it, and this
compiler accepts it. Seventeen occurrences in thirteen sources here write that
spelling, and **three** of them are under `tests/extended/`
(`binding.pas`, `binding_errors.pas`, `schema.pas`); the rest are in
`tests/dialect/`, where the dialect would go on admitting it. It is an
extension inside a conformance mode, which `doc/implementation-defined.md` §5
lists two of and this is not one, so it is a defect by that document's own rule
— but refusing it changes what `--std=extended` accepts in the direction a user
cannot work around, and the resolution that is probably right (refuse it in the
two conformance modes, admit it in the dialect with a clause of its own) is a
feature-sized change and not an adjudication. It goes on the list below.

### 3. §6.4.6 d) cannot fire between two variable-strings (§6.8.1)

The reader read §6.4.6's violation list literally:

> d) it shall be a dynamic-violation if T1 and T2 are produced from the same
> schema, but not with the same tuple (see 6.4.7).

and observed that §6.4.3.3.3 makes `string` a schema, so `string(5)` and
`string(10)` are produced from one schema with different tuples — which would
make `a := b` between them a dynamic-violation this compiler does not report.

It would also make §6.4.6 f) and its error c) dead for every pair of
variable-strings, which is the reading's own warning sign. §6.8.1 settles it:

> Any primary whose type is S, where S is a subrange of T, shall be treated as
> if it were of type T. … **Any primary whose type is a string-type shall be
> treated as if it were of the canonical-string-type.**

The canonical-string-type is a required type (§6.4.3.3.1), not a type produced
from the `string` schema, so T2 is never produced from that schema and d) has
nothing to fire on. **CONFIRMED** — the compiler is right.

That sentence is the third time this one paragraph has decided a question here:
it is why a subrange answers for its host (ADR-0018) and why a set-constructor
is uncommitted between packed and unpacked (ADR-0093). It is worth reading
whole before concluding that a rule about *types* reaches an expression.

### 4. `index` folds, so §6.3.2 compiles (§6.7.6.7, §6.8.2)

§6.3.2 is the standard's own example of a constant-definition-part, and it ends

```pascal
hex_string = '0123456789ABCDEF';
hex_digits = hex_string[1..10];
hex_alpha  = hex_string[index(hex_string,'A')..index(hex_string,'F')];
```

The last line did not compile: *the value of constant 'hex_alpha' is not a
compile-time constant*. §6.8.2 makes an expression nonvarying unless it
contains a variable, a non-static type-name, a function declared by the
program, or `eof`/`eoln`, and NOTE 1 adds the three that need a variable as a
parameter — `index` is none of those, so it belongs in a constant-expression.

Neither of the two reasons that keep a required function out of this folder
reaches it. `trunc` and the six real-valued ones are refused because a real
constant is carried as the text that was written and never converted, and
`substr` because its result is a string and a constant string here is its own
literal, *named* (ADR-0068). `index` returns an **integer** and its operands
are literals already in the pool, so it needs neither a conversion nor a name.
It had simply never been given an arm, and the two-argument branch of the
folder was written for `succ(x,k)` and `pred(x,k)` and asked their question of
everything that reached it — so the refusal was silent, unlike the eight that
say which restriction they are.

This is the third required function that arm has missed. ADR-0054 found
`succ(x,k)`, `pred(x,k)` and `length`; `index` was beside them and was not
looked for, because the sweep asked which functions §6.8.2 *permits* and not
which ones the folder *handles*.

### 5. A variant-part-value names the tag field its variant part declares (§6.8.7.3)

Two sentences of §6.8.7.3 require it, and this compiler read neither:

> A tag-field-identifier in a variant-part-value shall be the field-identifier
> associated with the selector of the variant-part corresponding to the
> variant-part-value … The field-identifier, if any, associated with the
> selector of a variant-part **shall have an applied occurrence in the
> tag-field-identifier of each variant-part-value** corresponding to the
> variant-part.

and, of the whole field-list-value,

> For each field-list-value that corresponds to a field-list, each
> field-identifier associated with a component of the field-list shall have
> **exactly one** applied occurrence as a field-identifier closest-contained by
> the field-list-value.

The selector is such a component, so omitting it gives zero occurrences where
exactly one is required. It is a "shall" with no Annex D entry, so §5.1 e)
applies: it is reported and the program refused.

**Three of the four shapes of this rule were already checked** — a
tag-field-identifier written for a tagless variant part, one naming a field
that is not the selector, and the tag given as an ordinary field-value are each
refused with their own message. Only the omission was missed, and the reason is
visible in the grammar:

```
variant-part-value = 'case' [ tag-field-identifier ':' ]
                       constant-tag-value 'of' '[' field-list-value ']' .
```

The bracket is there for a variant part whose selector has **no**
field-identifier, which is a real case and is now in the corpus as `bare`. It
was read as a licence to leave out one that exists.

`tests/extended/structvalue.pas` was one of the programs writing it, with a
comment asserting the rule the compiler implemented — "without one the variant
part is tagless and nothing is stored" — which is wrong twice over: a variant
part's taglessness is a property of the type and not of the value, and the
compiler stored the tag anyway. The corpus was edited, which is the langspec-audit
skill's own strongest warning sign; the two sentences above are why it is the
corpus and not the check that was wrong.

### 6. Reading a string at end-of-file is reported (§6.10.1, D.97)

> D.97 6.10.1 — When read is applied to text file f, it is an error if the
> buffer variable f^ is undefined, if f0.M is not Inspection or Update, if
> either f0.L or f0.R is undefined, or if **f0.R=S()**.

`f0.R=S()` is end-of-file. The clause is about `read` and not about one of its
forms, and this compiler reported it for the char-type form — which reaches the
buffer variable through §6.10.1 b)'s `v := f^; get(f)` — and for the numeric
forms, whose "it shall be an error if s is empty" catches the same position.
§6.10.1 e) and f), the two string forms, reached neither and answered with
spaces and the null-string. One read procedure gave two answers to one clause,
which is worse than either answer: an implementation may leave an Annex D error
undetected, but `doc/implementation-defined.md` §3 then has to say so, and a
list saying "read at end-of-file is unreported" would have been false of three
forms out of four.

What is **not** changed is end-of-line. NOTE 6 and NOTE 7 give that position its
own answer — "if eoln(f) is initially true, then no characters are read, and
the value of v is the null-string" — and it stays: at end-of-line there is a
line terminator still to read and at end-of-file there is not.
`readstr` is unaffected, because §6.7.5.5's auxiliary text file is written with
a `writeln` and the line terminator that appends is what keeps `eof` false
while the values are read.

**This changes what a working program does.** A program reading strings past
the end of its input used to get null-strings and now stops. It belongs in
release notes, not in a compiler change alone.

### 7. E.29 named the wrong end of the string

`doc/implementation-defined.md`'s E.29 said a Boolean written with an explicit
width is "padded on the left and truncated from the left". §6.10.3.5 makes
writing a Boolean equivalent to writing `'True'` or `'False'` as a
character-string, and §6.10.3.6 then says

> if 1 <= TotalWidth <= n, the **first** through TotalWidth-th characters in
> that order.

so the leftmost characters survive and `true:2` is `TR`. The compiler has
always written `TR`, and `tests/extended/fieldwidth.pas` has had all four
widths since it was written. Only the sentence was wrong — which is the class
of defect ADR-0164 was written about, one no oracle here can contradict,
reached this time through a clause rather than through a clause *number*.

## Consequences

Four fixes, six new or extended cases, and six mutations killing six
different tests:

| Fix | Case | Mutation |
|---|---|---|
| §6.7.3.2 padding | `tests/extended/fixedstring_param.pas`, `tests/extended/trap_param_capacity.pas` | Sema refuses again → both fail; the runtime fills with `?` instead of spaces → `fixedstring_param` alone fails |
| §6.8.7.3 tag field | `tests/extended/structvalue_errors.pas`, `tests/extended/structvalue.pas` | the arm is disabled → `structvalue_errors` fails |
| §6.7.6.7 `index` | `tests/extended/constexpr_required_functions.pas` | the arm is disabled → that case fails |
| §6.10.1 at eof | `tests/extended/trap_read_eof.pas` | the guard is removed → that case alone fails, `readstring` and `trap_readstr_eof` still passing, which is the evidence that `readstr` is untouched |
| the arena counter | `tests/extended/str_arena_loop.pas` | the bump is removed → that case stops with *more string values are live at once than the string arena holds* |

Nine scenarios were added, under `@extended:6.7.3.2`, `@extended:6.4.6`,
`@extended:6.8.7.3`, `@extended:6.8.2`, `@extended:6.7.6.7` and
`@extended:6.10.1`; §6.7.3.2 and §6.10.1 are new to the cited set.

`doc/sop.md` §7's arena row said "a fourth would have nothing looking for it".
This is that fourth, and it is the shape the row was written about — it is not
in `EmitString` at all — so `str_arena_loop.pas` gained a loop for it in the
same change and the row now says a fifth.

`pas_str_pad` is the only new runtime entry point, and it is `pas_*`, so
`foreign-reserved` and `runtime-isoc` are undisturbed. `PadsToFixedString`,
`ConstStrLen` and `ConstStrAt` are the new procedures, each entered by the
cases above.

Two corpus programs lost something. `tests/extended/binding_errors.pas` had a
`padded` procedure that existed only to pin the refusal in fix 1, and nothing
about it was ever a question about binding; `tests/extended/structvalue.pas`
had the non-conforming record-value of fix 5 and gained the conforming tagless
one it was reaching for.

### What this record does not do

It does not resolve the discriminated-schema parameter form of §2 above, which
is the one finding here that would take something away from a working program
and is therefore a change with its own record to write. `doc/roadmap.md` carries
it.

It does not revisit `ExpDigits`, which ADR-0169 declined and E.27 has stated
since ADR-0064, nor the `bind` of a non-file bindable variable, which ADR-0167's
third reader found and ADR-0170 documented.

**And it closes ADR-0168's list, which is a claim worth being careful about.**
The seven above are the seven that record wrote down. They are not the seven the
four readers found — the reports held "roughly two dozen findings", and what
survived into ADR-0168 was one reader's summary of each group. A finding that
was not written down that day is not on any list now, and no oracle here will
raise it.
