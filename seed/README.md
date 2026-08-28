# The seed

The `.ll` files here are a working Afterschool Pascal compiler, in LLVM IR,
committed to this repository. They are what makes the tree buildable now that
stage 0 is gone (ADR-0085): `clang` assembles them into a compiler, and that
compiler translates the three sources under `selfhost/` into the one
`cmake --build` puts in `build/bin`.

```sh
clang -Wno-override-module seed/*.ll build/lib/libpasrt.a -lm -o pascalc
./pascalc selfhost/aptypes.pas -o aptypes.ll
./pascalc --import selfhost/aptypes.pas selfhost/apfront.pas -o apfront.ll
./pascalc --import selfhost/aptypes.pas --import selfhost/apfront.pas \
          selfhost/compiler.pas -o pascalc.ll
```

**How many files there are is the seed's business, and both CMake and
`tests/checks/llc_check.sh` match them with a glob.** The compiler is three
§6.13 program-components since ADR-0233, so a refreshed seed is three modules
named after them — `aptypes.ll`, `apfront.ll`, `compiler.ll` — and
`seed/refresh.sh` removes the old ones before writing them, since a module left
behind from a build with more components would be linked in beside the new ones
and two definitions of the same program is a link error about a file nobody
wrote.

**A seed from before the split still works, and that is the point of a seed.**
`pascalc.ll` is one module holding the whole compiler as it was at v3.0.0; it
assembles into a compiler that translates the three sources perfectly well,
because what a seed has to be is a *working compiler*, not a mirror of the
current source layout. It is replaced at the next release, not at the split.

It is **IR rather than a binary** because ADR-0006 made textual `.ll` a
first-class output of this compiler — "the backend that survives the rewrite" —
and this is what that was for. A binary would be a quarter the size and
unreadable; this can be diffed, and a reviewer who wants to know what it does
can read it.

## What it is, exactly

Generated from the compiler's own sources at the commit it was last refreshed,
by the compiler built from those same sources. Its provenance is therefore the
repository's own history and nothing else — but that is a claim about a chain,
not something a reader can check by inspection, which is the trusting-trust
problem in its ordinary form. Tag `v0.1.0` is the last commit where a C++
compiler in this repository could reproduce a compiler from source alone;
`src/` itself was deleted at version 3 (ADR-0232), and `ddc.sh` takes its copy
from that tag rather than from the working tree.

## That chain has been checked once, by diverse double-compiling

**2026-08-18, at commit `ef49570`, against LLVM 21.1.8 — PASS.**

David A. Wheeler's diverse double-compiling, run by `seed/ddc.sh`:

1. build the `v0.1.0` C++ compiler, whose code generator is LLVM's;
2. have it translate today's `selfhost/compiler.pas`, and link that — **A**;
3. `build/bin/pascalc`, which came from the seed the ordinary way — **B**;
4. have A and B each translate `selfhost/compiler.pas`, and compare *those*.

They were identical: 7,024,210 bytes, sha256
`399b9cdc2e9422ae16ae5bd89c0eba9f1df4adbb729a66411104dfad7ee7925b`.

A and B are deliberately **not** compared to each other — ADR-0025 settled that
two backends' assembler text is not comparable, which is exactly why the
comparison is made one stage further on. What makes it evidence is that the two
compilers reached the same source through unrelated implementations, so a seed
carrying behaviour `selfhost/compiler.pas` does not account for would show up
here.

**The window closed at ADR-0233 and will not reopen.** `v0.1.0` has no
`--import`: handed a compiler that is three program-components it reports
`no interface named 'aptypes' has been exported` and stops, and it cannot link
them separately either. `ddc.sh` now runs, says THE WINDOW HAS CLOSED, and
exits 0. The result above is the only one that will ever be obtained, which is
why it is dated here rather than left in a log. `doc/sop.md` §7 carries the gap
that leaves.

**What it does not establish.** `v0.1.0` is this project's own earlier compiler,
so the two implementations are diverse but not independently *authored*. This
rules out a seed that drifted from its source. It does not rule out a mistake
present in both — the same caution `doc/sop.md` §7 records for the differential
oracle and for `langspec-audit`'s readers, and for the same reason: one author,
one reading.

**Re-run on 2026-08-18 at commit `95a7268`, after every commit message in the
repository was rewritten — also PASS**, at 7,074,541 bytes and sha256
`4a718afb16e63b08e972706f6476eb26b50c5d1460c97bdfb98ff86fb536228d`. The figures
differ from the first run because `selfhost/compiler.pas` has changed since;
each line above is a statement about the source at the commit it names, not a
constant. It is recorded because the rewrite moved tag `v0.1.0`, which
`ddc.sh` resolves by name, and a check that silently stopped resolving its own
starting point would have reported nothing.

**The window closes on its own and nothing will announce it.** The check works
only while the `v0.1.0` compiler still accepts `selfhost/compiler.pas`, and
every feature the compiler starts *using* risks ending that. Version 3 did not
close it — `--std=extended` is still what the v0.1.0 binary is given, that one
being a v2 compiler; what changed is that *today's* compiler is handed no flag,
which is the shape this check has always had (an old implementation reading a
new source). `ddc.sh` says so in
as many words when it happens, and reports it as a skip rather than a failure —
there would be nothing to fix. The dated line above is what survives; the
ability to repeat it is not guaranteed.

## It is x86-64 Linux only

The first two lines are a `target datalayout` and a `target triple`, and they
are not decoration: ADR-0028 records a segfault caused by leaving the datalayout
unstated, because the compiler's own size and alignment rules have to be the
ones the assembler uses. A seed carries the target it was generated for.

So **the repository is x86-64 Linux only** where before it was whatever LLVM
and a C++ compiler supported. Porting means generating a seed on the new
target, which needs a working compiler there first — from `v0.1.0`'s C++, or by
cross-compiling this IR. That cost is stated here rather than discovered.

**The second of those two is cheaper than this paragraph implies, and it has
been measured.** Replacing the first two lines with another target's and running
`clang --target=... -c` on each seed module produces a valid object for
aarch64-linux-gnu from the whole file — the frame layouts LLVM computes from
this module are identical under both targets' datalayouts, over 4501 sizes and
offsets, so nothing inside it is x86-64's but those two lines. What stops the
build is `PAS_JUMP_SIZE` in the *runtime*, `jmp_buf` being 200 bytes here and
312 there. `doc/roadmap.md`'s
[Cross-platform support](../doc/roadmap.md#cross-platform-support) has the
numbers and what they come to. None of it has been run, only linked.

## Its licence

The seed is the compiler's own sources in another form, so it is under the same
GNU General Public License version 3 or later, and those sources are
the corresponding source the GPL asks for — committed beside it, in this
repository, at the commit the seed was generated from. It carries **no** file
header of its own: it is generated, and a notice written into it would be
rewritten by the next refresh. `../LICENSE` and `../COPYING.RUNTIME` are the
authority. Note the runtime exception does *not* reach the seed — the seed is
the compiler, not the runtime.

## Refreshing it

**At release tags, not per commit.** The seed is 10.2 MB and 242,000 lines;
regenerating it whenever the compiler changes would rewrite all of it on every
commit that touches the compiler, which is most of them. A refresh after
ADR-0233 also changes the *set* of files, `pascalc.ll` giving way to one module
per program-component — which is one more reason it belongs at a release, and
why the `seed-is-current` CI job compares the set as well as the contents.

Nothing forces a refresh, and nothing needs to: an older seed builds a newer
compiler for as long as the sources stay within what the seed
accepts — a one-module seed building a three-component compiler included.
When it does not, the build fails at the first stage with an ordinary
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
Since ADR-0233 the bound that matters is the worst of *three* translations, and
it is not the program's: `buffer-headroom` reports which component set it.

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
