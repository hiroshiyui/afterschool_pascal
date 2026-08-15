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

## It is x86-64 Linux only

The first two lines are a `target datalayout` and a `target triple`, and they
are not decoration: ADR-0028 records a segfault caused by leaving the datalayout
unstated, because the compiler's own size and alignment rules have to be the
ones the assembler uses. A seed carries the target it was generated for.

So **the repository is now x86-64 Linux only** where before it was whatever
LLVM and a C++ compiler supported. Porting means generating a seed on the new
target, which needs a working compiler there first — from `v0.1.0`'s C++, or by
cross-compiling this IR. That cost is stated here rather than discovered.

## Refreshing it

**At release tags, not per commit.** The file is 6.5 MB and 157,000 lines;
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
