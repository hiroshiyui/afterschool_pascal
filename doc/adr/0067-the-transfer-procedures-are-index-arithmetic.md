# 67. The transfer procedures are index arithmetic, and nothing else

Date: 2026-08-13

## Status

Accepted.

## Context

Three required procedures of ISO 7185 were never implemented, and three
documents said the standard was complete. §6.6.5.4's `pack` and `unpack` and
§6.9.5's `page` were rejected under both standards.

They were **missed rather than declined**, and the shape of the miss is worth
recording. `pack` and `unpack` appear in `isRequiredName` — so that §6.6.3.7
can refuse passing one as a parameter — and nowhere else: the names were known
to the compiler and the calls were never wired up. `page` was absent entirely.
A documentation audit found it, by compiling a probe rather than reading prose;
nothing in the test corpus had ever named them, so every oracle agreed the
compiler was finished.

All three are required procedures of ISO/IEC 10206:1991 too (§6.7.5.4, §6.9.5),
so this was one gap in both standards rather than a stage-1 leftover.

§6.6.5.4 does not describe an operation. It gives a statement sequence each
procedure is *equivalent to*:

> Then the statement `pack(a,i,z)` shall be equivalent to
> ```
> begin k := i;
>   for j := u to v do begin zz[j] := aa[k]; if j <> v then k := succ(k) end
> end
> ```

where `u` and `v` are the smallest and largest values of the packed array's
index-type, and `unpack(z,a,i)` is the same with the assignment reversed.

## Decision

**What is left of §6.6.5.4 here is the index arithmetic and the range check.**
The procedures exist to convert between two representations, and this compiler
has only one: §6.4.3.1 leaves `packed` entirely to the implementation and
`llvmType` packs nothing, so a packed array and an unpacked array of the same
component type have the same layout. The representation change is therefore
vacuous, and the copy is a `memcpy`.

That is a fact about this compiler and not a shortcut, so it is written where
the code is: were `packed` ever to mean something, `emitTransfer` is the one
function that would have to grow the component-wise loop back. Nothing else
would change, because nothing else knows how the components travel.

**The bounds are checked once, before anything is copied.** The equivalence
subscripts `aa[k]` on each iteration and §6.5.3.2 makes an out-of-range
subscript an error, so the error condition is the array bounds and needed no
new rule. `k` runs monotonically from `i`, so the two ends are the only values
that can leave the array — and checking first means a program that stops leaves
the destination untouched, where a per-component check would leave a partial
copy behind. The message is the one an ordinary subscript gives, because it is
the same error.

**`i` is checked against the *unpacked* array's index-type and never against
the packed one's.** §6.6.5.4 says so — "assignment-compatible with the
index-type of the type of a" — and it is the rule a reader is most likely to
invert: the packed array's bounds say *how many* components move, and `i` says
where in `a` they start. `tests/transfer.pas` packs from 1, from the middle and
from the last position that fits, which is where an off-by-one lives.

**One arm checks both procedures, and names the roles rather than the
positions.** `pack(a, i, z)` and `unpack(z, a, i)` take the same three things
in a different order, and every rule is about the roles — so `TransferArgs`
sorts them out once and the checks read as "the unpacked one", "the packed
one", "the index". The order is the thing most likely to be written the wrong
way round, and it is the only thing the two statements disagree about.

**§6.9.4 e) threatens the destination, and only that one.** Which side that is,
is the whole difference between the two procedures — the source is read. This
is the third call site on ADR-0046's list of threats, after ADR-0065's.

**`page` keeps its state in the runtime, because the state is the file's.**
§6.9.5's effect on the file is implementation-defined and here it is the ASCII
form feed. What the standard *fixes* is the rest: the pre-assertion is
`writeln(f)`'s, the implicit `writeln` happens only "if f.L is not empty", and
the buffer variable becomes totally-undefined.

That middle clause is the one that cost something. Nothing in the runtime
tracked whether the current line had anything on it, because nothing had needed
to — so `struct pas_file` gained a flag and `PAS_FILE_SIZE` went 112 → 120,
with `fileSize` in the Pascal compiler moving with it. `irtest.sh` is what
checks the two still agree, as it did when ADR-0060 moved the same number.

The flag follows what was *written* rather than that a write was attempted,
because a zero field width may write no characters at all (§6.10.3.1) — so
`write(f, x:0); page(f)` writes no blank line, which is the case that
distinguishes the two readings.

**Sema supplies `output` when `page` is written without a file.** CodeGen never
inspects names (ADR-0008), so the bare form is given the same `standardFileRef`
a `write` with no file gets, and by the time anything downstream looks, `page`
has exactly one argument.

## Consequences

**ISO 7185 is complete now**, and the claim is worth less than it was: three
documents asserted it while it was false. What makes it true is not the
implementation but `tests/transfer.pas`, `tests/page.pas`,
`tests/transfer_errors.pas` and `tests/trap_pack.pas` — the corpus that had
never named these procedures is why every oracle agreed.

**`verify/` gained nothing.** There is no new arithmetic: the range check is
the array rule already proved for every bound and every index, applied to the
two ends of a run instead of to one subscript. A rule restating that would be
the kind ADR-0013 warns against.

**A new `StdProc` enumerator has to be appended**, because the AST dump prints
it as an ordinal and both compilers must agree on the number. The three went at
the end for that reason and not because they belong there — `difftest` has
caught this twice before as "a number one apart".

**`packed` on an array is now load-bearing in Sema and inert in CodeGen**,
which is a split worth naming. §6.6.5.4's first two requirements are about
which array is which, so Sema refuses `pack(a, i, a)` and `pack(z, i, a)`;
CodeGen then treats the two identically, because they *are* identical. The
compiler is strict about a distinction its code generator does not make.

### What this does not do

**`page` on a file being read is refused at run time, not compile time.** The
pre-assertion is `writeln(f)`'s and that is checked where every other file-mode
error is — in the runtime, by `pas_out`. A text file's mode is not a static
property here.

**No page structure is modelled.** §6.9.5 says the effect of *inspecting* a
textfile a page was written to is implementation-dependent, and here it is
simply a character in the file: `tests/page.pas` reads one back and finds
`chr(12)`. Nothing counts pages, and `eoln` does not treat the separator
specially.

**`packed` still means nothing to the representation.** That is ISO 7185
§6.4.3.1's own latitude and was decided long before this record; what is new is
only that two procedures now exist whose entire purpose is the conversion this
implementation has no need to make.
