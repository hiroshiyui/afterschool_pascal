# 97. The required identifiers are symbols

Date: 2026-08-15

## Status

Accepted. Completes what ADR-0087 stopped short of and what ADR-0088 named as
the answer to its own remaining gap.

## Context

ISO 7185 §6.2.2.10:

> Required identifiers that denote required values, types, procedures, and
> functions shall be used as if their defining-points have a region enclosing
> the program.

This compiler recognised them **by name**: `BuiltinType` answered for the five
required types, `LookupBuiltin` for the required functions, and a name-keyed
dispatch for the required procedures. Two consequences, one loud and one silent:

- **§6.2.2.9 could not fire.** ADR-0088's rule works by stamping the *symbol* a
  lookup found; a required identifier was no symbol, so `ord` used in one
  procedure and then declared by the program went unreported. DEV112, DEV264 and
  DEV265.
- **A required type could not be redeclared at all.** `type integer = char` was
  accepted and then *ignored* — a type-denoter asked `BuiltinType` before the
  scope, so `var v: integer` still meant the built-in and nothing said so. A
  required *function* already shadowed correctly, because every call site
  consulted the scope first and fell back to the builtin only on nil.

## Decision

**The required types become ordinary `skType` symbols in the scope that already
existed.** `InstallPredefined` has declared `true`, `false`, `maxint` and the
Extended Pascal required constants at scope depth 0 since those features landed;
the types simply join them. Every `BuiltinType` call site then loses its
pre-check and lets the ordinary scope lookup answer, and `BuiltinType` is
deleted.

**The required functions become `skRequired`, a marker kind and not `skFunc`.**
A real `skFunc` would make `IsInvocable` true and send `abs` and `succ` through
`CheckArguments`, which is a much larger project for no conformance gain.
`skRequired` is inert — `IsInvocable`, `ResultTypeOf` and `IsVariable` all
answer as they did for a name that resolved to nothing — so every existing "did
the program declare one?" branch still falls through to the builtin path.

**`LookupUser` is what preserves that.** The convention every one of those
branches was written against is *nil means the required one* (ADR-0087), so a
lookup that now finds a marker has to answer nil while still **recording the
applied occurrence**, which is exactly what §6.2.2.9 needs. One wrapper over
`Lookup`, substituted at the six places that ask what a name the program wrote
denotes.

**The required procedures are deliberately not declared.** They buy no verdict —
each already yields to a user declaration through the nil path — and declaring
them would make `selfhost/compiler.pas` itself non-conforming, since it applies
the required `bind` before declaring its own `Bind`. That is a rename and a
separate change.

## Consequences

**465 cases pass, no golden moved, and the compiler still compiles itself.** The
three programs are refused with ADR-0088's own wording, which is the test of
whether this was put in the right place: §6.2.2.9 needed no new rule, only a
symbol to see.

**Two `case` statements over `symKind` needed an arm**, because a Pascal `case`
with no match traps at run time. Both were already non-exhaustive — neither has
an arm for `skInterface` — so appending an enumerator exposed a latent trap that
is still there for that one.

**Three always-true wrappers were unwound**, in `ResolvePointer`,
`ResolveRestricted` and `ResolveType`, and two comments justifying the deleted
pre-check were rewritten rather than dropped: their claim (that a qualified name
cannot reach a required type) is still true, for a different reason.

**One message changed and nothing pins it**: `writeln(integer)` now says
*"'integer' is a type and has no value"* where it said *"undeclared identifier"*.
More accurate, and the visible consequence of required types being symbols.

**`^integer` inside a type-definition-part now takes the pending path**, since
`ResolvePointer` no longer short-circuits. That is the correct reading of
§6.2.2.9 — an `integer` defined later in the same part must win — and it means
`t^.elem` is nil for longer, so a fault here would surface as a nil dereference
inside a type part rather than as a wrong answer. CONF027 and
`tests/extended/required_identifiers.pas` are what exercise it.

### What this does not do

**It does not enforce §6.2.2.9 for a name used before a var-part written after a
procedure declaration.** `procedure p; begin writeln(zz) end; var zz: integer;`
is accepted under `--std=extended`, because `checkDeclarations` merges the
constant, type and variable parts by source position (ADR-0069) while procedure
declarations remain a separate list walked afterwards. It costs no verdict here
and affects user names exactly as much as required ones.

**It does not fix the type-name alias.** `type foo = char` writes `foo` onto the
shared `char` singleton, so a later bare `char` variable is *reported* as `foo`.
Pre-existing, unchanged by this, affecting no program's meaning — now recorded
in `doc/implementation-defined.md` rather than left for the next reader to
rediscover.
