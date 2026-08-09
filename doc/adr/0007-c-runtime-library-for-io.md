# 7. Formatted I/O lives in a C runtime library

Date: 2026-08-09

## Status

Accepted

## Context

`writeln(x:8:3)` has to become something. The alternatives were to have codegen
build `printf` calls inline — computing format strings at compile time — or to
call into a support library written in C.

Pascal's output rules are not a thin layer over `printf`. Field width is a
runtime value, not a literal; the default form for `real` is floating with a
sign slot; `boolean` writes as a word; a written string is a pointer and a
length rather than a NUL-terminated buffer. Encoding that as generated IR means
generating format-string logic, and the interesting cases — `write(x:w:p)` with
computed `w` and `p` — cannot be resolved at compile time at all.

Files, `read`/`readln`, and `eof` are coming, and none of them lower to a single
libc call.

## Decision

`runtime/pasrt.c` compiles to `libpasrt.a` and is linked into every generated
program. Codegen emits calls to a small, explicit interface:

```
pas_write_int(long long, int width)
pas_write_real(double, int width, int prec)
pas_write_bool(int, int width)
pas_write_char(char, int width)
pas_write_str(const char *, int len, int width)
pas_writeln(void)
pas_runtime_error(const char *)
pas_halt(int)
```

`width < 0` and `prec < 0` mean "not given", which is how the absence of a
Pascal field-width specifier is carried to run time.

Runtime checks call `pas_runtime_error`, which flushes stdout, writes to stderr,
and exits 1. Codegen emits the check and an `unreachable`.

## Consequences

Output formatting is readable C that can be tested and corrected without
touching codegen, and it is the natural home for file I/O when it arrives.
Codegen stays a translator: it selects a function by static type and passes
values through.

Generated programs now depend on `libpasrt.a` being findable — the build path is
baked in as `APASCAL_RUNTIME_DIR`, overridable with `AFTERSCHOOL_PASCAL_RUNTIME`
(see ADR-0009).

Calls are not inlined into the generated program, so output is a call per item.
Irrelevant next to the write itself.

The runtime is C, not Pascal, and stays C after the bootstrap. It is the layer
where the operating system is reached, and self-hosting has never meant writing
the standard library's syscall wrappers in the language itself.
