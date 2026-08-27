# 226. A string-valued constant-expression

Date: 2026-08-27

## Status

Accepted.

## Context

ADR-0224's audit returned two over-strict findings. This is the first: a
constant-definition could not be given a string-valued or string-compared
expression.

```pascal
const k = 'ab' + 'cd';          const k = trim('ab  ');
const k = substr('abcd',2,2);   const k = ('ab' = 'ab');
```

Each was refused with *the value of constant 'k' is not a compile-time
constant* — a complaint about the program, for a program the clause admits.
ISO/IEC 10206:1991 §6.8.2 makes an expression nonvarying unless it contains a
variable-identifier, a schema-discriminant, a bound-identifier, a
field-designator-identifier, a non-static type-name, or a function-identifier
declared by the program or naming `eof`/`eoln`; NOTE 1 adds `empty`, `position`
and `LastPosition`, and says why — they need a variable as a parameter. None of
the forms above contains any of that.

**The recorded reason was false, and the audit proved it rather than doubted
it.** `doc/implementation-defined.md` and two comments in the compiler said
`substr` was refused because "its result is a string, which has no scalar form
to fold to". Three things were wrong with that at once:

- It named `substr` alone. Concatenation, `trim` and the six string relational
  functions were refused too.
- A relational yields a **boolean**, so the reason could not cover it however
  charitably read.
- The folder *already produced string constants*. `const c = ta[1: 'ab' + 'cd';
  2: 'xy']` was accepted and yielded `abcd` — §6.8.7's structured-value-
  constructor gave the same computed string somewhere to live. It was the
  constant-definition path alone that declined.

A string constant here **is** a literal, named (ADR-0068): `constValue` holds an
`nkStr`, which is exactly what the substring-constant fold has built since
ADR-0054. There was never anywhere it could not go.

## Decision

Fold them. Concatenation and the six relational operators in
`EvalConstBinary`; `trim`, both forms of `substr` and the six relational
*functions* in `EvalConstCall`.

**The operators and the functions are different rules, and the fold keeps them
apart.** §6.8.3.5 extends the shorter value with spaces, so `'ab' = 'ab '` is
true. §6.7.6.7's EQ is *"( (s1v = s2v) and (n1 = n2) )"* — the padded
comparison **and** equal lengths — so `eq('ab','ab ')` is false. LT is defined
over prefixes rather than by padding. The compiler has carried that distinction
in a comment beside the builtin kinds since the functions landed, and this is
the first thing to depend on it. `tests/extended/constexpr_strings.pas` prints
both beside each other.

**Where the characters come from is the one real difference from the substring
fold.** That one *narrows* a run the literal already put in the pool. A
concatenation has nothing to narrow, so it appends; and a **char** constant has
no run at all, its character living in the symbol, so `trim('x')` and
`substr('x',1,1)` append too. Those are the only three producers.

**§6.7.6.7's third error condition is asked as `j > n - i + 1`, not by forming
`i + j - 1`.** Both are a program's constants and may be anything, and this
compiler's own integer arithmetic traps on overflow (ADR-0014) — so
`substr(s, maxint, maxint)` would have stopped the compiler instead of
reporting the error the clause names. `tests/extended/constexpr_string_errors.pas`
has that line in it.

## It landed in both front ends, and difftest is why

`src/` is the reference front end and difftest compares Sema over every source
in the tree, so a folder change lands twice or the gate fails — which it did,
naming exactly the case written two commits earlier to pin the old refusals.

Porting found a fourth stale claim: `evalConstCall` opened with
`if (c->args.empty() || c->args.size() > 2) return false;`, so the
three-argument `substr` was refused before any of the new code was reached. The
same doc comment sat above it. The C++ side is in some ways the easier of the
two — a `StrLit` holds a `std::string`, where the Pascal has to append to the
pool — but it needed one thing the Pascal did not: `unsigned char` casts in the
comparison, because Pascal's `char` is an ordinal 0..255 and C++'s may be
signed, and a plain `<` would order the high half of the character set below
the low one.

## Consequences

**One restriction struck from `doc/implementation-defined.md` §6**, which is
what makes a restriction legitimate under §5.1 c). Eight refused required
functions remain, all real-valued, and that entry is now true as written.

**A set-valued constant-expression is still refused**, and that half of the old
sentence was right: the folder builds no set node, so there is nothing for the
result to be. `const c = [1] + [2]` is refused, and with the same generic
message the audit complained about for strings — so that criticism now stands
alone against this one case, and is recorded in the document rather than fixed
here.

**The catalogue ordinal moved and the gate caught it.** The string-relational
fold contains a case-statement over `binaryOp`, ahead of the one
`partial_cases.txt` already described, so `EvalConstBinary:binaryOp:1` became
`:2`. An arm inserted ahead of a catalogued case would otherwise have silently
re-pointed the entry at a different statement. That is `kind-exhaustive` doing
the job ADR-0145 built it for, on a change that had nothing to do with it.

**Coverage held without a ratchet regeneration.** The first draft lost eight
statements — the char-constant paths and four operator arms no case reached —
which is `line-coverage` doing what a ratchet is for: the six relational
operators are six arms of one case-statement, and exercising two says nothing
about the other four.

## Alternatives

**Leave it and correct only the documentation.** ADR-0224 corrected the
documentation, and that was the right first step because the *claim* was false
whether or not the fold ever landed. But §5.1 c) does not permit a restriction,
and the reason recorded for this one turned out not to exist — a restriction
with no cause is a defect with a note attached.

**Fold only what §6.3.2's examples need.** Its `hex_alpha` example needs
`index`, which folded already. Doing the minimum would leave `substr` refused
next to a substring-constant that is not, which is the inconsistency this
started as.

**Fold the real-valued ones too, in the same change.** They are the audit's
other finding and they are a different problem: they need a decimal-to-binary
conversion and a formatter to write the result back, and the accuracy of the
result is implementation-defined (§6.8.2 NOTE 2 says so in as many words). That
is a decision with a cost, not a mechanism that was missing, and it gets its own
record.
