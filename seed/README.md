# The seed

`pascalc.ll` is a working Afterschool Pascal compiler, in LLVM IR, committed to
this repository. It is what makes the tree buildable now that stage 0 is gone
(ADR-0085): `clang` assembles it into a compiler, and that compiler translates
`selfhost/compiler.pas` into the one `cmake --build` puts in `build/bin`.

```sh
clang -Wno-override-module seed/pascalc.ll build/lib/libpasrt.a -lm -o pascalc
./pascalc --std=extended selfhost/compiler.pas -o next.ll
```

It is **IR rather than a binary** because ADR-0006 made textual `.ll` a
first-class output of this compiler — "the backend that survives the rewrite" —
and this is what that was for. A binary would be a quarter the size and
unreadable; this can be diffed, and a reviewer who wants to know what it does
can read it.

## What it is, exactly

Generated from `selfhost/compiler.pas` at the commit it was last refreshed,
by the compiler built from that same source. Its provenance is therefore the
repository's own history and nothing else — but that is a claim about a chain,
not something a reader can check by inspection, which is the trusting-trust
problem in its ordinary form. Tag `v0.1.0` is the last commit where `src/`
existed and a C++ compiler could reproduce a compiler from source alone.

## That chain has been checked once, by diverse double-compiling

**2026-08-18, at commit `3eab2cd`, against LLVM 21.1.8 — PASS.**

David A. Wheeler's diverse double-compiling, run by `seed/ddc.sh`:

1. build the `v0.1.0` C++ compiler, whose code generator is LLVM's;
2. have it translate today's `selfhost/compiler.pas`, and link that — **A**;
3. `build/bin/pascalc`, which came from `seed/pascalc.ll` the ordinary way — **B**;
4. have A and B each translate `selfhost/compiler.pas`, and compare *those*.

They were identical: 7,024,210 bytes, sha256
`399b9cdc2e9422ae16ae5bd89c0eba9f1df4adbb729a66411104dfad7ee7925b`.

A and B are deliberately **not** compared to each other — ADR-0025 settled that
two backends' assembler text is not comparable, which is exactly why the
comparison is made one stage further on. What makes it evidence is that the two
compilers reached the same source through unrelated implementations, so a seed
carrying behaviour `selfhost/compiler.pas` does not account for would show up
here.

**What it does not establish.** `v0.1.0` is this project's own earlier compiler,
so the two implementations are diverse but not independently *authored*. This
rules out a seed that drifted from its source. It does not rule out a mistake
present in both — the same caution `doc/sop.md` §7 records for the differential
oracle and for `langspec-audit`'s readers, and for the same reason: one author,
one reading.

**The window closes on its own and nothing will announce it.** The check works
only while the `v0.1.0` compiler still accepts `selfhost/compiler.pas`, and
every feature the compiler starts *using* risks ending that. `ddc.sh` says so in
as many words when it happens, and reports it as a skip rather than a failure —
there would be nothing to fix. The dated line above is what survives; the
ability to repeat it is not guaranteed.

## It is x86-64 Linux only

The first two lines are a `target datalayout` and a `target triple`, and they
are not decoration: ADR-0028 records a segfault caused by leaving the datalayout
unstated, because the compiler's own size and alignment rules have to be the
ones the assembler uses. A seed carries the target it was generated for.

So **the repository is now x86-64 Linux only** where before it was whatever
LLVM and a C++ compiler supported. Porting means generating a seed on the new
target, which needs a working compiler there first — from `v0.1.0`'s C++, or by
cross-compiling this IR. That cost is stated here rather than discovered.

## Its licence

The seed is `selfhost/compiler.pas` in another form, so it is under the same
GNU General Public License version 3 or later, and `selfhost/compiler.pas` is
the corresponding source the GPL asks for — committed beside it, in this
repository, at the commit the seed was generated from. It carries **no** file
header of its own: it is generated, and a notice written into it would be
rewritten by the next refresh. `../LICENSE` and `../COPYING.RUNTIME` are the
authority. Note the runtime exception does *not* reach the seed — the seed is
the compiler, not the runtime.

## Refreshing it

**At release tags, not per commit.** The file is 6.6 MB and 160,000 lines;
regenerating it whenever the compiler changes would rewrite all of it on every
commit that touches `selfhost/compiler.pas`, which is most of them.

Nothing forces a refresh, and nothing needs to: an older seed builds a newer
compiler for as long as `selfhost/compiler.pas` stays within what the seed
accepts. When it does not, the build fails at the first stage with an ordinary
diagnostic, and the fix is to refresh from the last commit that did build.

**Two different things can put a source outside it, and only one is a
language feature.** The obvious one is a source using something the seed's
compiler cannot parse. The other is **capacity**: the seed carries its own
fixed table bounds, and `poolMax` — the characters of identifier and literal
text one compilation may intern — is the one that has actually run out, because
the compiler is its own largest input and `PoolAdd` does not deduplicate. The
symptom is the seed reporting *"out of string space"* against
`selfhost/compiler.pas`, and raising the constant in the source does **not**
help: the seed still holds the old bound and is what has to read the file.

That is the one case where a refresh is not optional and cannot wait for a
release tag, because until it happens no diagnostic can be added to the
compiler at all. Do it on a tree that *builds* — the last green commit plus the
one-line bound — so the artefact being trusted is the product of a green tree.
[ADR-0095](../doc/adr/0095-the-string-pool-was-the-ceiling.md) is the record of
the time this happened, and argues why a policy about rewrite noise should not
become a policy about capability.

```sh
seed/refresh.sh          # regenerate from the current source, then verify
```

`refresh.sh` does not just regenerate: it rebuilds the compiler from the new
seed and requires the result to reach a fixed point, so a seed is never
committed without evidence that it reproduces itself.
