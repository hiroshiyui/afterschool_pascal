# 83. The compiler has a command line

Date: 2026-08-14

## Status

Accepted.

## Context

ADR-0081 implemented §6.5.1 and §6.7.6.8 NOTE 2, so an Extended Pascal program
can read the arguments it was started with. ADR-0082 made
`selfhost/compiler.pas` an Extended Pascal source, so this one may. What was
left was to use it.

The interface being replaced was
`Compile(output, source, ircode, options, imports)`: four positional files, with
the standard in a file holding one word and §6.13's components **concatenated**
into a single file because a program that cannot name a file cannot open several
(ADR-0033, ADR-0079). Every harness built those two scratch files before every
invocation.

## Decision

**`pascalc` takes flags** — `-o`, `--std=`, `--import`, `-h` — the same
spellings `pascalc-s0` uses, and its own usage text.

**Twelve program-parameters are the command line.** A program-parameter is a
*name*, not a subscript, so there is no way to ask for "the k'th": `Arg(k)` is a
twelve-arm `case`, and twelve is a real limit on how many arguments this
compiler can be given rather than a notional one, because the parameter list is
written out when the compiler is compiled. None of the twelve is ever opened —
only `binding(argk).name` is read — and an unbound one is how the list ends,
§6.12 binding only the positions an argument reached.

**Every flag is an exact word and every value is the argument after it**, which
is what lets the whole of the parsing be `EQ` on strings. `EQ` rather than `=`
because §6.8.3.5's operators pad the shorter operand with spaces and §6.7.6.7's
`EQ` compares the lengths too — `-o` and `-o ` are not the same flag, and only
one of the two comparisons says so.

**The files it works on are bound to computed names** (§6.7.5.6). That is the
half of ADR-0081 that is not about reading: `bind` is the only way a program
names a file while it is running, and the source, the IR and each imported
component all have names that were computed rather than positions that were
fixed.

**`--import` may be repeated.** The concatenated file is gone, and with it the
one place ADR-0079 had to defend a design against the language rather than on
its merits.

**It stops at the IR, and the usage text says so** — with the `clang` line a
reader needs. No standard Pascal program can start another, so this is where a
self-hosted driver ends.

## Consequences

**Stage 2 still equals stage 3**, and 435 sources still agree stage for stage
between the two compilers. The compiler that reads its own command line
reproduces itself.

**Three harnesses got shorter.** `difftest.sh`, `irtest.sh` and
`producttest.sh` each wrote an options file and an imports file before every
invocation; none does now. `irtest.sh`'s `build()` passes one `--import` per
component instead of concatenating them into a scratch file, so what it hands
the Pascal compiler is what a user would type.

**One more identifier had to move.** `BindingType` is a required type
identifier, and the compiler had a global variable of that name — the same
collision as `value` and `bindable`, found the same way, and renamed the same
way (by token position: the string `'bindingtype     '` is interned in the
compiler's own symbol table and a text substitution would have rewritten it).

**ADR-0033's constraint is retired for this compiler, and only for it.** That
record said the standard could not be a flag "because ISO 7185 gives a program
no access to its command line beyond its program parameters, and those are
files". Every word of that is still true of ISO 7185 — what changed is that this
compiler is no longer written in it. The constraint was met three times
(`--std`, ADR-0024's single source file, ADR-0079's concatenated imports); it
binds the first and third no longer, and the second not at all, an include
mechanism being a thing ISO/IEC 10206:1991 also lacks.

### What this does not do

**It does not link.** Assembling and linking what `pascalc` writes is a separate
`clang` invocation, permanently — see the usage text, which is the one place a
user will look.

**It does not take more than twelve arguments or eight `--import`s.** Both are
array bounds and both report rather than truncate.

**It does not read `argv[0]`.** §6.12 binds the program-parameters and the
program's own name is not one of them, so the usage text says `pascalc` rather
than the name it was invoked by.

**It does not do what `main.cpp` does.** No optimisation level, no object
emission, no `--dump-*` selection — the Pascal compiler writes all three dumps
on every run, which ADR-0025 explains and this record does not change.
