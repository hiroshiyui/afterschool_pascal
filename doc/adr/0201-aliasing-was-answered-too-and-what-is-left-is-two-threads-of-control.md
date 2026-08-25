# 201. Aliasing was answered too, and what is left is two threads of control

Date: 2026-08-25

## Status

Accepted. Withdraws the fork ADR-0151 deferred, picks the shape a concurrency
construct here must have, and declines to build it.

## Context

ADR-0151 named the dialect's memory-safety model — affine ownership with
scope-based release — and deferred one question with a criterion rather than a
mood:

> The remaining fork — ARC or borrow-checking — is deferred, and the trigger is
> named. It becomes decidable at the first construct that lets **two live names
> reach one owned value**.

It listed four such constructs and called concurrency the one that certainly
demands it. `doc/roadmap.md`'s table has since read *Blocked, and it is what
unblocks the two aliasing rows*.

This record was started to pick the concurrency construct. It begins with four
probes instead, because ADR-0151's own first section is the reason to look
before designing: the model it named had been in the language since before the
project began, and nobody had noticed.

## What the probes found

**1. Containment forbids both candidates on `^T`.** ADR-0117 makes the dialect
accept everything Extended Pascal accepts and mean the same by it. This is a
conforming Extended Pascal program:

```pascal
new(p); q := p; dispose(p);
```

§6.6.5.3 makes a subsequent use of `q^` an error, and this processor does not
detect it — `doc/implementation-defined.md` §3, ADR-0019, undiminished. Both
candidates change what that program means. ARC changes what `dispose` does and
what a pointer costs; borrow-checking **refuses** it. Either breaks
containment, and `^T` is the only reference type an ISO program has. Compiled
under `--std=extended` and `--std=afterschool`, the program behaves
identically today, as it must.

So the fork as posed cannot be applied to the pointer the question was about.

**2. The dialect's answer to aliasing is refusal, given three times.** A file,
a handle and `owned ^T` are `IsAffine`, none may be copied, and `q := o` for a
plain `q` is refused in as many words: *it contains an owned pointer, and a
second name for one would dispose one variable twice*. There is no second name
for an owned value, so there is nothing for either candidate to govern.

**3. A borrow is already here, and was never named.** This runs, prints 2, and
balances:

```pascal
procedure Bump(var n: Node);
begin n.v := n.v + 1 end;
...
new(o); o^.v := 1; Bump(o^); writeln(o^.v)
```

`n` is a second name for what `o` owns, for the duration of the call — a
borrow. And it **cannot escape**: Pascal has no address-of operator (§6.1.9's
alternative `@` is refused, `torture.pas`), and `new` is the only thing that
produces a pointer, so no pointer can ever name what a `var` parameter refers
to. `kept := n` is refused as a type error, which is the whole enforcement.

A borrow whose lifetime is the borrowing activation, and it comes from the
language's poverty rather than from a checker. That is ADR-0151 §1's pattern a
second time: the property was already held, by construction, and unremarked.

Even the classic hazard is safe. `P(o, o)` where `P` is
`procedure P(var a, b: Own); begin a := take(b) end` is a self-move: `take`
empties the variable, the assignment puts the value back, `o` is not nil
afterwards and the heap balances `new=1 dispose=1 live=0`.

**4. Concurrency cannot be a library here.** The obvious escape — bind
`pthread_create` and leave the language alone — does not exist:

    parameter 1 of 'ext' cannot be a procedure or a function: what would cross
    is a code pointer and the link it runs under, and C takes one word

§6.6.3.1's procedural parameter is a code-and-link pair (ADR-0030) and a
foreign routine has no link. So a task's body cannot be handed to C, and any
concurrency here is a **language** construct or nothing.

## Decision

**1. The fork is withdrawn as posed.** "ARC or borrow-checking" is not a
question this language can answer, because the two differ about what may hold
an **escaping** alias to an owned value and the dialect has no such thing:
containment fixes `^T`, refusal covers the three affine kinds, and the borrow
that exists cannot outlive the call. What holds is stated instead: **affine
ownership, scope-based release, and a non-escaping borrow.** Nothing changes
meaning; what changes is that the roadmap's two undecidable rows become a
description.

**2. What is left of ADR-0151's trigger is exactly one thing: two threads of
control.** Every alias above is safe *because* there is one — a borrow cannot
outlive the call because the caller is not running during it. That sentence
fails the moment two activations run at once, and it is the only sentence that
does.

The other three constructs ADR-0151 listed do not reopen it. A handle as a
function result and a handle in a longer-lived structure are refusals to
relax — the reason they are refused is not a missing model; and a second
pointer to a disposed variable is ISO Pascal's own error, which containment
puts out of reach.

**3. The construct, when it lands, is share-nothing.** A task owns what it is
given; nothing is reachable from two tasks at once. That is not a preference —
it is the only shape under which all four findings survive. Anything that lets
two tasks name one variable reintroduces the escaping alias the language has
never had, and the model that would then be needed is precisely the one this
record has just shown unnecessary.

Concretely: a task, given ownership of what it works on; a typed channel to
send owned values between tasks; and a move where a value crosses. The
lineage is Pascal's own — Brinch Hansen's Concurrent Pascal put `process` and
`monitor` in the language in 1975, Ada took the rendezvous from that line, and
Pascal-FC carried processes, channels and monitors into teaching — so this is
the branch of the family that had concurrency before it had modules, and the
spelling should come from there rather than from a language with a different
memory model.

**4. It is not built here, and the reason is ADR-0116's.** No program in this
tree wants it. The compiler is one thread and must stay so — the seed compiles
it. The twelve dialect modules want a stream, a directory, an environment and a
process, and `PasProcess` gets its concurrency from the operating system
through `popen`, which needs no construct. A designed feature with no caller is
what ADR-0116's allocator was, and it did not survive contact.

**What would demand it, by name**: a socket module that serves more than one
client, which is the first thing on `doc/roadmap.md`'s list whose obvious
implementation is a thread per connection — and which has a cheaper answer,
`select`, that must be tried first, exactly as ADR-0187's copy retired the
address instead of modelling it.

**5. One prerequisite is concrete and can be recorded now.** Of the three
affine kinds only `owned ^T` moves: `take` is refused for a handle in as many
words — *nothing else has a value one variable can stop holding* — and there is
no move for a file. A task cannot be **given** a socket or a file until a
handle can move. Whatever demands concurrency will meet that first, and it is
a smaller increment than the construct.

## Consequences

**`doc/roadmap.md` loses two undecidable rows and one blocked one**, and the
question in *Answered, and where* changes from "aliasing waits on concurrency"
to what the probes found.

**AP has no clause and gets none.** AP 5.6 lets this specification state a
requirement ahead of the processor, and ADR-0195 built the gate that keeps the
marker and the triage honest — but ADR-0195 also says the mechanism is for the
next feature designed ahead of its implementation, "not for a standing
backlog". A concurrency chapter with no caller is a standing backlog, so the
decision lives here and the specification stays silent.

**The spelling is available and is not chosen here.** ADR-0140 lets the dialect
reserve no word-symbol, and three free positions exist for what this construct
needs: a declaration-initial identifier, where a conforming program may write
only `label`, `const`, `type`, `var`, `procedure`, `function` or `begin`; an
identifier followed by `of` at a type-denoter, where `of` is reserved and
follows only `array`, `set` and `file`, which is `array of T`'s own argument
(ADR-0125); and a statement-initial identifier followed by none of `(`, `:=`,
`[`, `.`, `^` or a terminator, which is `defer`'s (ADR-0175). Recording that
the positions exist is worth more than choosing words for a construct nobody
has asked for, and the words are settled where the caller is.

## What this does not do

**It does not make `^T` safe**, and cannot. ADR-0019's hole is ISO Pascal's,
containment keeps it, and `doc/implementation-defined.md` §3 declares it.

**It does not claim the borrow is checked.** It is *unformable*: there is no
syntax that turns a `var` parameter into a value that outlives the call. A
future feature that adds one — an address-of, a closure capturing by reference,
a reference-typed field — would break the property silently, and nothing here
would fail. That is a row for `doc/sop.md` §7.

**It does not decide a scheduler, a memory ordering, or what a channel costs.**
Those are the construct's, and the construct is not being built.

**It does not survey what other Pascals do in any depth.** Concurrent Pascal,
Pascal-FC and Ada are named as the lineage to read when the increment happens;
this record has not read them against a design, because there is no design.

## Alternatives rejected

**Building a scoped `cobegin … coend` now.** The cheapest construct to
implement and the wrong one: the tasks in it share the enclosing block's
variables, which is the escaping alias the language has never had, arriving
with no model to govern it. It would make the fork real rather than answer it.

**Deciding ARC or borrow-checking anyway**, to close the roadmap row. The row
closes here by being shown to be about a question the language does not have,
which is a better outcome than a coin-flip with a record attached.

**Binding `pthread_create` and calling concurrency a library matter.** Probed
and impossible: a procedural parameter is a code-and-link pair and C takes one
word. Recorded because it is the first thing anyone will try.

**Waiting for a caller before writing anything.** That is what ADR-0151 did four days
ago, and the cost is already visible: a roadmap row saying *blocked* about a
fork the language had settled three times by refusal, and a criterion whose
four triggers turn out to be one. What a caller decides is the
spelling and the shape of a channel; what it does not decide is whether the
dialect may have two escaping names for one owned value, and that is decided.
