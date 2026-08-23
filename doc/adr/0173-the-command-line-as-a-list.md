# 173. The command line as a list: `argcount` and `argument(k)`

Date: 2026-08-23

## Status

Accepted. AP 6.7.6.10.

## Context

A survey of what a daily program needs against the library (the roadmap,
*What blocks the library*) left three things open, and this was the smallest:
**a program cannot get its arguments as a list.** Neither standard gives a
program its command line at all; what this compiler offers is ADR-0081's
reading of ISO/IEC 10206:1991 §6.12 and §6.7.6.8 NOTE 2 — every file-type
program-parameter is bound to one argument, and `binding(p).name` reports it.
`selfhost/compiler.pas` reads its own command line that way: twelve bindable
program-parameters, opened never, and the first unbound one is the end of the
list, there being no other way to count (ADR-0158).

That is a shape a compiler can afford and a twenty-line program cannot. And a
**library** cannot offer it at all: a module has no program-parameters to
ask, and the runtime routine that would answer is a `pas_*` name AP §6.7.7.10
reserves from every `external` declaration. So this is a language feature by
elimination — the only kind the roadmap said it could be.

## Decision

**Two required function-identifiers, the dialect's alone.** `argcount` is an
integer, the number of arguments not counting the program's name; `argument(k)`
is a value of the canonical-string-type, the `k`-th, and `k` outside
`1..argcount` is an error reported by the runtime (Annex A.6). They name the
same sequence §6.12 binds the program-parameters to, so `binding(pk).name` and
`argument(k)` agree, and a program may use both.

**The shape is `int64`'s** (ADR-0128): a required identifier, which §6.1.3
makes shadowable, so a program of the contained standard that declares its own
`argument` — or its own `argcount`, as a variable even — keeps it.
`tests/dialect/inherits_extended.pas` declares both and is the containment
witness. Under the conformance modes the names are nobody's, and the answer
there is *unknown function*, which is Annex B's `int64` row and costs `src/`
nothing.

**A bare `argcount` is decided by Sema, not the parser.** `eof` and `eoln` are
turned into calls by the parser when no `(` follows, and the first version of
this did the same for `argcount` under the dialect. `tests/spec/`'s third
scenario refused it: a program with `var argcount: integer` is valid Extended
Pascal, and the parser had taken its variable away — a containment break
`dialect-containment` cannot see, because no corpus program uses that name.
So the rule is *ask the symbol, not the syntax* (ADR-0044): when Sema finds a
bare `argcount` whose nearest defining-point is the required marker, it builds
the call and hangs it off the `nkVar` as a husk (`vrCall`), which `EmitExpr`
and `EmitAddress` read first. `IsDesignator` already answers false for a
`vrSym` of nil, so `argcount := 1` and `read(argcount)` are refused by the
paths that exist. A declaration of the program's wins by being found first.

**The value points into `argv`.** Every other string-valued required function
takes from the arena (ADR-0111); this one need not, `argv` outliving every
statement, so the producer counter is not bumped. The length is a second
runtime call on a position the first has already admitted, because a string
value is a pointer and a length (ADR-0051) and the generated code asks for
each.

## Consequences

- `PasProcess` and every future module can take a program's arguments without
  the program declaring file variables it never opens. The compiler keeps its
  twelve: the feature has to be expressible in what `seed/pascalc.ll` accepts,
  and it is not yet.
- A seventh row in Annex B, with `tests/argument_refused_iso.pas` and
  `tests/extended/argument_refused.pas`; a sixth entry in
  `containment_exceptions.txt`; `builtinKind` grew by two and
  `kind-exhaustive` named every partial case that needed a decision.
- **What it does not do.** No `argument(0)` — the program's name is not an
  argument, and §6.12 never bound it. No environment here; `PasEnv` has that.
  No change to `binding` (E.19).

## Mutation

`pas_argcount` answering `argc` rather than `argc - 1`: `arguments` fails at
its first line and then segfaults reading `argv[3]`. The Sema gate widened to
`langStd <> stdIso7185`: `argument_refused` fails under `--std=extended` with
*unknown function 'argcount'* where *undeclared identifier* is expected — the
conformance surface moved.
