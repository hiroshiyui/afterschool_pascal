#!/usr/bin/env bash
#
# The AST is a variant record, and this is the only thing that checks it is
# read through the arm its tag selects.
#
# `selfhost/compiler.pas` has exactly one variant record -- `case kind:` appears
# once in 36,000 lines -- and it is the AST: 63 arms, read by the parser, Sema,
# both dump walkers and the code generator. ISO/IEC 10206:1991 6.5.3.3 makes
# reading a field of an inactive variant an **error**, and 3.1 lets a processor
# leave an error undetected. A wrong-arm read of a node is silent rubbish, and
# if the field is a pointer the next walk follows it.
#
# ADR-0118 is the rule that catches it: a write to a variant's field activates
# that variant, and a read of an inactive one traps. It was a *dialect* rule
# while there were conformance modes to keep it out of, and ADR-0223 was about
# building the compiler a second way to get it -- under `--std=afterschool`,
# used as a reader and never as the product. ADR-0232 removed the modes, so
# there is nothing to select and nothing to build twice: the guards are in
# whatever this compiler emits.
#
#     1 occurrence of the trap message -- a string constant
#                      the compiler *emits* into programs it compiles
#  2821 guards
#
# What is left is the sweep, which is the half that was ever doing the work:
# compile the compiler with itself, then read 1019 sources with the result and
# require none of them to trap.
#
# **What it cannot see.** 6.4.3.3 permits a variant part with no tag field, and
# there is then nothing to compare against -- doc/sop.md 7 carries that row. The
# AST's variant part has a tag, so this covers it; a second variant record added
# without one would be outside this silently.
#
# It compiles rather than runs: every pass that touches a node runs during a
# compilation, and running the compiled program tells you nothing about the
# compiler's own AST.
set -uo pipefail

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
cc=${1:-$root/build/bin/pascalc}
runtime=${2:-$root/build/lib/libpasrt.a}

if [[ ! -x $cc ]]; then
  echo "variant-check: no compiler at $cc" >&2
  exit 1
fi
if ! command -v clang >/dev/null; then
  echo "variant-check: no clang, so the guarded compiler cannot be linked" >&2
  exit 77
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# The guarded compiler: the compiler's own source, translated by the compiler.
# A failure here is not a skip -- the source this repository ships must compile
# with the binary this repository built, or the fixed point irtest.sh proves is
# about something else.
#
# Three program-components since ADR-0233, in the order
# selfhost/compiler.components gives, each translated with the ones before it
# as `--import` and all three linked together. The guards are counted over all
# three modules: they are one compiler, and ApTypes is where the AST's variant
# part is *declared*.
modules=(); imports=(); n=0
for component in $(cat "$root/selfhost/compiler.components") compiler.pas; do
  n=$((n + 1))
  if ! "$cc" "${imports[@]+"${imports[@]}"}" \
       "$root/selfhost/$component" -o "$work/ap$n.ll" \
       >"$work/gen.out" 2>"$work/gen.err"; then
    echo "variant-check: the compiler does not compile $component" >&2
    head -20 "$work/gen.out" "$work/gen.err" >&2
    exit 1
  fi
  imports+=(--import "$root/selfhost/$component")
  modules+=("$work/ap$n.ll")
done

# Summed in the shell rather than through `bc`, which is not among the
# documented dependencies -- `ca-certificates cmake make clang git python3` is
# the whole list, and a check that needs a seventh tool fails on every CI
# platform at once, which is how this was found.
guards=0
for module in "${modules[@]}"; do
  n=$(grep -c 'variant: the tag selects another arm' "$module" || true)
  guards=$((guards + n))
done
if (( guards < 100 )); then
  echo "variant-check: the guarded build has $guards variant guards in it." \
       "ADR-0118's check is not being emitted, so this would pass by asking" \
       "nothing -- which is the one way it must not pass" >&2
  exit 1
fi

if ! clang -O2 -Wno-override-module "${modules[@]}" "$runtime" -lm \
     -o "$work/pascalc-ap" 2>"$work/link.err"; then
  echo "variant-check: the guarded compiler did not link" >&2
  head -20 "$work/link.err" >&2
  exit 1
fi

# The corpus. One language, so a source is handed over as it is -- which is
# also why this now reaches sources the mode rule used to sort into three
# groups and compile three ways.
checked=0
trapped=0
while IFS= read -r src; do
  # Every dump runs, so both walkers are exercised and not only the four
  # passes -- ADR-0104's coverage corpus drives them the same way and for
  # the same reason.
  "$work/pascalc-ap" --dump-all "$src" -o "$work/out.ll" \
      >"$work/dump.out" 2>"$work/dump.err"
  checked=$((checked + 1))
  # The runtime's own wording, on the runtime's own stream. Matching the bare
  # message anywhere would match `--dump-all` of compiler.pas printing the
  # string literal the emitter carries -- which it did, on the first run.
  if grep -qs '^runtime error: variant:' "$work/dump.err"; then
    echo "--- $src: the compiler read a node through the wrong arm ---" >&2
    grep -hs '^runtime error: variant:' "$work/dump.err" | head -3 >&2
    trapped=$((trapped + 1))
  fi
done < <(find "$root/tests" "$root/selfhost" "$root/lib" "$root/lsp" \
              -name '*.pas' | sort)

if (( checked < 500 )); then
  echo "variant-check: only $checked sources were compiled, and the corpus is" \
       "larger than that -- a run that reaches nothing passes for the same" \
       "reason a clean one does" >&2
  exit 1
fi

if (( trapped > 0 )); then
  echo "variant-check: $trapped of $checked sources made the compiler read a" \
       "node through an arm its tag does not select" >&2
  exit 1
fi

echo "variant-check: $checked sources compiled by a compiler carrying" \
     "$guards variant guards; every node was read through the arm its tag" \
     "selects"
