# 9. Link by invoking `clang`

Date: 2026-08-09

## Status

Accepted

## Context

An object file is not a program. Something must combine it with `libpasrt.a`,
the C runtime startup files, and libc, and know where all of those live on this
system.

LLVM ships `lld`, which could be linked in or called directly. But a linker
invocation needs the correct `crt1.o`, `crti.o`, `crtn.o`, the dynamic loader
path, and the library search paths for the target — knowledge that varies by
distribution and that `clang` already has. Reproducing it means reproducing a
driver, which is a project of its own and one that breaks on other people's
machines rather than on ours.

## Decision

`pascalc` emits an object file, then runs:

```
clang <obj> -L<runtime-dir> -lpasrt -lm -o <exe>
```

and removes the object file unless `--keep-temps` was given. `clang` must be on
`PATH`.

The runtime directory is baked in at configure time as `APASCAL_RUNTIME_DIR`,
pointing into the build tree, and `AFTERSCHOOL_PASCAL_RUNTIME` overrides it so
an installed compiler can find its runtime elsewhere.

`-c` stops after the object file and `--emit-llvm` stops after IR, so neither
needs a linker at all.

## Consequences

Linking works on any system where clang works, including cross-compilation
later, and the compiler stays out of the business of tracking libc layouts.

The costs are real but bounded. `clang` becomes a run-time dependency of the
compiler, not just a build-time one. Invocation goes through `std::system`, so
paths are shell-quoted rather than passed as an argv array — fine for the paths
that occur in practice, and worth replacing with `posix_spawn` if it ever needs
to be robust against arbitrary filenames. And the linker's diagnostics reach the
user as clang's, not as ours.

The alternative to revisit, if the dependency becomes a problem, is calling
`lld` with paths discovered at configure time. That trades a run-time dependency
for a configure-time one, and it can be done without changing anything upstream
of object emission.
