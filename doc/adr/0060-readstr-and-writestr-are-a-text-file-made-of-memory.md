# 60. readstr and writestr are a text file made of memory

Date: 2026-08-12

## Status

Accepted.

## Context

ISO/IEC 10206:1991 §6.7.5.5 adds two string transfer procedures, and it does
not describe what they compute. It describes what they are *equivalent to*:

>     readstr-parameter-list = '(' string-expression ',' variable-access
>                              { ',' variable-access } ')' .
>
> the execution of `readstr(e, v1, ..., vn)` ... shall be equivalent to
>
>     begin rewrite(f); writeln(f, e); reset(f); read(f, v1, ..., vn) end
>
> where f denotes an auxiliary variable that the program does not otherwise
> contain, which possesses the required type text. ... It shall be an error if
> the equivalent of `eof(f)` is true upon completion.

and, for the other direction,

>     writestr-parameter-list = '(' string-variable ',' write-parameter
>                               { ',' write-parameter } ')' .
>
>     begin rewrite(f); writeln(f, p1, ..., pn); reset(f); read(f, ss) end
>
> ... It shall be an error if the equivalent of `eoln(f)` is false upon
> completion.

Everything the two procedures do — how a real is parsed, what a field width
means, where a string read stops, what a fixed-string destination is padded
with — is therefore already written down somewhere else, in §6.10. The clause
adds no formatting rule of its own. What it adds is a text file with no
external entity behind it.

## Decision

**The auxiliary variable is a `struct pas_file` backed by memory, and it is
the whole feature.** `fmemopen` gives readstr a text stream over the string's
characters and `open_memstream` gives writestr one that grows a buffer; both
are ordinary `pas_file`s in every other respect — `istext` is set, `compsize`
is 1, the mode is reading or writing. Every `pas_read_*` and `pas_write_*`
primitive is then reused **unchanged**, which is the standard's own
equivalence implemented rather than paraphrased.

That is what makes the feature small in the compiler. `WriteStmt::str` and
`ReadStmt::str` say which statement this is; when one is set, Sema skips the
leading-argument-is-a-file detection and leaves `file` null, and CodeGen calls
the runtime for a handle instead of taking the address of a file variable.
The loops over the parameters were pulled out into `emitWriteArgs` and
`emitReadArgs`, which take the handle and **do not know which kind of file
they were given**. No branch inside them is new.

**The `writeln` in the equivalence is a real newline.** readstr's memory
stream is the characters followed by `'\n'`, and that is not decoration: it is
what keeps `eof` false while the values are being read, so the error condition
means what the clause says it means. A readstr that runs off the end is the
only way to reach it.

**writestr's error condition is the string store's capacity check.** The
statement ends in `read(f, ss)`, which takes at most the destination's
capacity; `eoln(f)` is false afterwards exactly when more was written than the
destination could hold — which is §6.4.6's rule that a string value longer
than the capacity is an error, already emitted by `pas_str_store_fixed` and
`pas_str_store_var` for every string assignment. So the second error condition
needed no code at all, only the observation that it was the same one.

**The characters readstr reads from are copied.** `readstr(e, i, e)` reads
into the very variable it reads from, and §6.7.5.5 does not forbid it —
unlike writestr, whose clause does forbid a write-parameter accessing the
destination. One `malloc` and a `memcpy` are what make the permitted case
mean what it says.

**The auxiliary file is heap-allocated per statement, not a static.** A
variable-access or a write-parameter may call a function whose body contains a
readstr, so the two can nest; `tests/extended/stringtransfer.pas` has a
`writestr` inside the write-parameters of another. It is deliberately **not**
on the open-file list ADR-0032 keeps, because §6.7.5.5 makes it a variable the
program does not contain — block exits and non-local `goto`s have no business
closing it.

**`PAS_FILE_SIZE` went from 96 to 112**, for the two fields the memory stream
needs. That constant is the compiler's half of an interface whose point is
that the storage is opaque (ADR-0021), so it is stated in one header, asserted
against `sizeof` at build time, and mirrored by `fileSize` in the Pascal
compiler — where `irtest.sh` is what checks the two agree.

## Consequences

`verify/` gained nothing and no existing lowering changed.

**Both statements are parsed by name**, exactly as `read` and `write` are: the
parser has no scope, so it cannot ask whether the program declared its own
`readstr`. Under `--std=extended` the two names are therefore claimed, which
is a **deviation** — §6.7.5.5 makes them required *identifiers*, so a
conforming processor would let a program redeclare them. It costs the ISO 7185
corpus nothing (`tests/readstr_iso.pas` uses both names as its own) and it
follows the precedent `read` and `write` already set rather than inventing a
second rule; a compiler that wanted to close it would have to move the
recognition into Sema, where the required *functions* are already decided.

**The parameters are write-parameters and variable-accesses, so nearly every
diagnostic was already written.** `tests/extended/stringtransfer_errors.pas`
produces twelve, and half of them were already written — an enumeration cannot
be written, a fraction length belongs to a real, a value is not somewhere to
read into, and a protected parameter cannot be threatened by either statement.
Only the six that name `readstr` and `writestr` are this feature's own, and
all six are about the one parameter these two procedures have that `read` and
`write` do not.

**The grammar's three insistences needed six files.** A parser stops at its
first error, so `(`, the first `,` and `)` are one program apiece per
procedure — `stringtransfer_open`, `_comma` and `_close`, each with a `2` for
the writestr half. None is a program a person would write, and that is the
reason they exist: a corpus that always writes the comma cannot tell a parser
that requires it from one that does not, and a mutation making it optional
survived until these were added.

**A substring may be either end of it.** §6.5.6's substring-variable is a
variable-access, so it is a readstr target and a writestr destination alike,
and both took the branch `emitAssign` and `emitRead` already had for one
(ADR-0057). The destination case is the one worth naming: a substring's
capacity is `hi - lo + 1` and is not its type's, so it cannot go through
`emitStringStoreValue` and calls `pas_str_store_fixed` with the length
`emitString` computed.

**Releasing the auxiliary file is checked by a sanitiser, not by the corpus.**
It is the one thing here that no `.out` file can see: a program that never
calls `pas_str_write_end` prints exactly the same characters and exits zero.
A mutation deleting that call survived every oracle and was killed by an ASan
run over `tests/extended/stringtransfer.pas` — 51 allocations, all of them
`open_memstream`'s. That is the division ADR-0019 already drew for pointers:
where the ISO condition and the emitted check would be the same statement
twice, the sanitiser is the evidence rather than a test.

**A check that could not be reached was deleted rather than kept.** The
grammar requires at least one parameter after the comma, so "writestr needs
something to write" was unreachable the moment the parser was written — the
mirror of `write`'s check, which *is* reachable because `write` may be written
with no parameter list at all.

### What this does not do

**§6.7.5.5's aliasing rule is not enforced**: "it shall be an error if any of
the write-parameters accesses the referenced string-variable". That is a
run-time property of two designators, like ADR-0027's rule about a variant
created by `new` and ADR-0057's about a substring, and it is refused for the
same reason — the compiler has no way to decide it and the runtime is not told
enough to.

**A `readstr` of a string is greedy**, which is §6.10.1 e) rather than a
choice made here, and it means a second string variable after one receives the
null-string. That is not an error: the line marker is still unread, so `eof`
is false at completion. `tests/extended/stringtransfer.pas` prints it, because
it is the case a reader would file a bug against.
