# 87. A required procedure may be declared away

Date: 2026-08-14

## Status

Accepted.

## Context

ADR-0086 adopted the BSI Pascal Validation Suite and recorded three defects it
found on its first run. Two were fixed there. This is the third:

> **§6.6.4.1** — a program may redefine `write` as its own procedure. Not fixed
> here.

CONF116 declares `procedure write(var a: integer)` and `procedure get(var a:
integer)`, calls both, and prints PASS when the value is 4. `get` worked. This
compiler ran the *required* `write`, printed `0`, and **reported nothing** —
the failure mode ADR-0085 warned about, a program that is silently wrong rather
than rejected.

The rule is ISO 7185 §6.2.2.10: "Required identifiers that denote required
values, types, procedures, and functions shall be used as if their
defining-points have a region enclosing the program", with §6.6.4.1 the
procedures' half of it. A declaration in the program-block hides one.

**Every other required procedure already had this, and none of them cost
anything.** Required procedures are not symbols here. `CheckProcCall` reads a
`Lookup` that answers nil as "the required one", so a program that declares
`get` gets its own `get` because the lookup succeeds and the standard branch is
never reached. Twenty-odd names work that way.

Six did not: `read`, `readln`, `write`, `writeln`, and — under
`--std=extended` — §6.7.5.5's `readstr` and `writestr`. The reason is
§6.8.2.3's grammar:

    procedure-statement = procedure-identifier ( [ actual-parameter-list ]
                            | read-parameter-list | readln-parameter-list
                            | write-parameter-list | writeln-parameter-list ) .

An actual-parameter-list has no field widths and a write-parameter-list does,
so the parser has to know which alternative it is reading — and the only thing
that tells it is the name. So the six were recognised in `ParseIdentStatement`,
which is a pass with no scope, and the question of what the name *denotes* was
settled where it could not be asked. ADR-0060 stated the consequence for its
own two and called it a deviation; the other four were never written down at
all, in the ADRs or in `doc/implementation-defined.md`.

## Decision

**The parser decides the statement's shape; Sema decides what the name
denotes.** The same division ADR-0044, ADR-0053, ADR-0066 and ADR-0071 each
reached — ask the symbol, not the syntax — for the fifth time. (ADR-0086
predicted a sixth, having counted one of the four twice.)

Three parts:

**The parser yields the name whenever what follows it can continue a
designator.** `write := 5`, `write[i] := 5`, `write.f := 5`, `write^ := 5` and
§6.8.6.4's `write(i)^ := 5` are assignments to something the program declared,
and none of the five is a statement any parameter list begins. `write := 5` was
a *syntax error* before this, which is how far the commitment reached.

**Sema looks the name up and, when the program declared it, builds the call the
statement really is.** `RedefinedFamily` is that lookup; it hands back an
`nkProcCall` that `CheckArguments` then checks like any other, and the node the
parser built is left behind as a **husk** — `wrCall`/`rdCall` is what every pass
after Sema reads. That is ADR-0066's shape and it is there for ADR-0066's
reason: `CheckStmt` takes a raw pointer and cannot replace the node its parent
holds.

**The two string-transfer procedures give up their parameter list's shape.**
§6.7.5.5 writes it as `'(' string-variable ',' write-parameter, ... ')'`, and a
parser that requires that comma has already decided the statement is a
writestr. So the list is parsed as an ordinary write-parameter-list and **Sema
moves the string out of it**, once the name has been looked up. `wrIsStr` is all
the parser contributes, and it says only which word was written. This retires
ADR-0060's stated deviation.

## Consequences

**CONF116 passes**, and it is the only program in the 812 whose verdict moved —
`tests/bsi/expected.tsv` says so, in the same change, which is what that
catalogue is for.

**Nothing new checks a call.** Every diagnostic in
`tests/redefine_required_errors.pas` — wrong arity, a value where a `var`
parameter is wanted, a function used as a procedure, a variable used as a
procedure — comes from code written for ordinary calls. Only one message is
new, and it is the one the grammar demands: a declared `write` takes no field
width, because §6.8.2.3 gives an actual-parameter-list none.

**§6.6.3.7 came out right without being touched.** "The actual parameter shall
not denote a required procedure or function" is enforced against a `Lookup` that
answered nil, so a *declared* `write` is now passable as a procedural parameter
and the required one is still refused. The rule and the fix are the same
question asked once.

**CodeGen gained one test per arm and `verify/` gained nothing.** A redefined
family statement lowers to `EmitUserCall`, which has existed since ADR-0016; no
arithmetic, conversion or comparison changed, so no rule in `verify/` describes
anything different.

**A check that had never been reachable had to be written.** `writestr(s)` —
the string and nothing to write — was impossible while the comma was the
parser's rule, so the "needs something to write" test sat only on the
ordinary-write path. Making the case reachable is what exposed the omission:
the statement compiled and ran, writing nothing. Two of the four rewritten
`stringtransfer_*` tests are that program.

**A broken `readstr` had been given `input`.** With the string missing, the
statement fell through to the file detection and asked for the standard input,
so a program that never mentions `input` was told it must list it — a rule it
was not breaking. A readstr reads from no file at all, and that is now what the
code says.

**Four tests moved from the parser to Sema and their prose moved with them.**
`stringtransfer_open`, `_open2`, `_comma` and `_comma2` pinned §6.7.5.5's
parameter list as a *grammar* rule. The rule is unchanged and the enforcement is
one pass later, so each file's comment says so; the two `_close` tests are
byte-identical, because the parser still knows which of the six words it read
and a message naming the wrong one would name a procedure the program never
wrote.

**The restriction was never in `doc/implementation-defined.md`.** ADR-0073
wrote that document by compiling a probe per entry, and §6 lists three
restrictions; a program's inability to declare its own `write` was not among
them, and was not added when ADR-0086 found it and deferred it. It is fixed
rather than documented, so nothing is added now — but the gap is the same one
ADR-0074 recorded: the document a reader consults instead of the source is the
worst place for an omission.

### What this does not do

**It does not make the parser scope-aware, and must not.** What the parser now
decides is which *statement form* it is reading, which is a question about
tokens. Every question about what a name denotes is Sema's, and the six names
are the only ones the parser still recognises at all.

**It does not give a block back the required procedure it declared away.** A
program-block that declares `write` hides it for the whole program, nested
blocks included — §6.2.2.10 puts the required one in a region *enclosing* the
program, not between a block and the one nesting it. `tests/redefine_required.pas`
is written around that: the two readings appear in one program only because the
declarations that hide them are nested.

**It does not touch the required *functions*.** `abs`, `ord`, `succ` and the
rest were never parsed by name — an identifier with an argument list is a call
wherever it stands in an expression — so `CheckCall` has taken the user's
declaration since it was written. `tests/extended/redefine_stringtransfer.pas`
keeps a function beside a procedure for that reason: the half that always
worked, next to the half that did not.
