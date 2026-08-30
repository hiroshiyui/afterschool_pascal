#!/usr/bin/env bash
# Afterschool Pascal -- an ISO 7185 / ISO/IEC 10206:1991 Pascal compiler.
# Copyright (C) 2026 Hui-Hong You
#
# This program is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the Free
# Software Foundation, either version 3 of the License, or (at your option)
# any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
# for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program.  If not, see <https://www.gnu.org/licenses/>.

# The compiler this repository produces, exercised as a user would reach it.
#
#   producttest.sh <path-to-pascalc> <runtime-dir> [files...]
#
# `pascalc` is `selfhost/compiler.pas` translated by the seed and linked by
# CMake, and until this existed nothing tested that artefact. `irtest.sh` looks
# thorough enough to cover it and does not: it builds a stage-1 compiler of its
# own in a temporary directory, so the binary in `build/bin` could be missing,
# stale or built from the wrong source and every test would stay green. What is
# checked here is the *build wiring* -- that the product exists, runs, and
# compiles a program correctly -- rather than the compiler, which the 276 cases
# and the stage-2/stage-3 fixed point already cover.
#
# It is deliberately small for that reason. Two programs, because one is not
# evidence that the wiring works for anything but itself.
set -u

pascalc=${1:-}
runtime=${2:-}
if [[ -z $pascalc || -z $runtime ]]; then
  echo "usage: producttest.sh <pascalc> <runtime-dir> [files...]" >&2
  exit 2
fi
shift 2

here=$(cd "$(dirname "$0")" && pwd)
root=$(dirname "$here")
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

if [[ ! -x $pascalc ]]; then
  echo "producttest: $pascalc is not executable -- was it built?" >&2
  exit 1
fi

# A caller may name others. The default pair is a small program and a larger
# one; there is one language, so neither stands for a mode.
if [[ $# -gt 0 ]]; then
  files=("$@")
else
  files=("$root/tests/hello.pas" "$root/tests/extended/otherwise.pas")
fi

failed=0
checked=0
for f in "${files[@]}"; do
  name=$(basename "${f%.pas}")
  expected="${f%.pas}.out"
  if [[ ! -f $expected ]]; then
    echo "producttest: $name has no .out to compare against" >&2
    failed=$((failed + 1))
    continue
  fi

  # A command line, since ADR-0081: the compiler reads its own arguments
  # through the binding of its program-parameters, so -o is a flag like any
  # other compiler's rather than the file it used to be.
  if ! timeout 120 "$pascalc" "$f" \
       -o "$work/ir.ll" >/dev/null 2>"$work/gen.err"; then
    echo "--- $name: pascalc did not translate it ---" >&2
    cat "$work/gen.err" >&2
    failed=$((failed + 1))
    continue
  fi
  # A compiler that exits 0 and writes nothing would otherwise be reported as a
  # link failure, which names the wrong component.
  if [[ ! -s $work/ir.ll ]]; then
    echo "--- $name: pascalc exited 0 and wrote no IR ---" >&2
    failed=$((failed + 1))
    continue
  fi

  # Linking is the one part of a driver's job that does not port: neither
  # standard has process control, so the Pascal compiler stops at the IR and
  # something outside it assembles and links. Here that is this script.
  if ! clang -Wno-override-module "$work/ir.ll" "$runtime/libpasrt.a" -lm \
       -o "$work/prog" 2>"$work/link.err"; then
    echo "--- $name: what pascalc wrote did not link ---" >&2
    cat "$work/link.err" >&2
    failed=$((failed + 1))
    continue
  fi

  stdin_file="${f%.pas}.in"
  [[ -f $stdin_file ]] || stdin_file=/dev/null
  "$work/prog" <"$stdin_file" >"$work/out.txt" 2>/dev/null
  checked=$((checked + 1))
  if ! diff -u "$expected" "$work/out.txt" >"$work/diff.txt"; then
    echo "--- $name: pascalc built a program with the wrong output ---" >&2
    cat "$work/diff.txt" >&2
    failed=$((failed + 1))
  fi
done

# --- the version it reports is the one the project carries -------------------
#
# Pascal has no preprocessor, so CMake cannot substitute the number into
# compiler.pas: it is written there as a constant and checked here, which is
# the arrangement `fileSize` and PAS_FILE_SIZE already have for the same
# reason -- two files that cannot include one another, and a disagreement that
# is checked rather than trusted. A compiler that misreports its own version
# makes every bug report worse than no version at all.
want=$(sed -n 's/^project(afterschool_pascal VERSION \([0-9.]*\).*/\1/p' \
       "$root/CMakeLists.txt")
have=$("$pascalc" --version 2>/dev/null | sed -n 's/^pascalc (Afterschool Pascal) //p')
checked=$((checked + 1))
if [[ -z $want ]]; then
  echo "--- version: CMakeLists.txt names no project VERSION ---" >&2
  failed=$((failed + 1))
elif [[ $want != "$have" ]]; then
  echo "--- version: the project is $want but pascalc says '$have' ---" >&2
  failed=$((failed + 1))
fi

# --- and that -h documents every flag it accepts ----------------------------
#
# Derived from ParseArgs rather than compared against a golden, because the
# thing worth knowing is not what the help text says -- it is whether the help
# text and the argument parser still describe the same compiler. A golden would
# agree with whichever of the two was edited last.
#
# Until this was written the release checklist said "confirm the -h output
# matches the flags that actually exist" and a person did it by eye, once a
# release. tests/checks/coverage.py is what surfaced it: `Usage` was entered by
# no case in the corpus, so nothing ran -h at all.
help_text=$("$pascalc" -h 2>/dev/null)
checked=$((checked + 1))
if [[ -z $help_text ]]; then
  echo "--- help: pascalc -h wrote nothing ---" >&2
  failed=$((failed + 1))
else
  undocumented=""
  while IFS= read -r flag; do
    [[ -n $flag ]] || continue
    probe=$flag
    [[ $flag == --target=* ]] && probe="--target="
    case $help_text in
      *"$probe"*) ;;
      *) undocumented="$undocumented $flag" ;;
    esac
    # Two spellings, because a flag that takes a *joined* value cannot be
    # compared with EQ against the whole argument: `--target=aarch64-linux-gnu`
    # is matched by its prefix, `EQ(substr(a, 1, 9), '--target=')`. Deriving
    # only the first form left --target= undiscoverable here, so the check that
    # exists to notice an undocumented flag could not have noticed that one
    # (ADR-0156).
  done < <({ grep -o "EQ(a, '-[^']*')" "$root/selfhost/compiler.pas" |
               sed "s/EQ(a, '//; s/')//"
             grep -o "EQ(substr(a, 1, [0-9]*), '-[^']*')" \
                  "$root/selfhost/compiler.pas" |
               sed "s/.*, '//; s/')//"; } | sort -u)
  if [[ -n $undocumented ]]; then
    echo "--- help: pascalc accepts flags -h does not mention:$undocumented ---" >&2
    failed=$((failed + 1))
  fi
fi

# --- and the same question of the driver ------------------------------------
#
# `tools/pascalcc` is the half of the compiler that links, so it is where -c,
# -O0..-O3 and <file>.o are documented and nowhere else -- `pascalc -h` is the
# compiler's own help and knows nothing about them. Its --help printed the
# licence header and stopped one line before the first option, because it was a
# line range (`sed -n '2,20p'`) into a file whose lines had moved. Every option
# was invisible and nothing here asked, while the check directly above had been
# asking the same question of the compiler for a release.
#
# Same derivation as above and for the same reason: the flags come from the
# case arms that parse them, so this compares the help text against the
# argument parser rather than against a golden that would agree with whichever
# was edited last.
#
# One arm is written as a family rather than as itself, in the help text and in
# the parser both, so it is matched by the prefix they share: `-O0|-O1|-O2|-O3`
# against `-O`, which the text spells `-O0 .. -O3`. The catch-all arms (`-*`,
# `*.o`, `*`) name no option and are dropped -- which is also what drops
# `--std=*`, the arm ADR-0232 left behind to accept and ignore the flag, and
# `--dump-*`, which is a family and not a catch-all: it names a real group of
# options, the help text spells it `--dump-<what>`, and what this check cannot
# do is compare a pattern against a placeholder. The section below is what
# asks whether it works instead (ADR-0239).
driver=$root/tools/pascalcc
help_text=$("$driver" --help 2>/dev/null)
checked=$((checked + 1))
if [[ -z $help_text ]]; then
  echo "--- help: pascalcc --help wrote nothing ---" >&2
  failed=$((failed + 1))
else
  undocumented=""
  while IFS= read -r flag; do
    [[ -n $flag ]] || continue
    # A substring test is not enough here and the check above gets away with
    # it only because its flags are long: `-c` occurs inside `--coverage`, so
    # deleting the line that documents `-c` left this passing. The flag has to
    # stand as a token -- at the start of a line or after a space or comma, and
    # ended the same way -- which is how the text actually writes it
    # (`--emit-llvm,-S`, `-h, --help`).
    if [[ $flag == -O[0-9] ]]; then
      # Written as the range `-O0 .. -O3` rather than one line per level.
      [[ $help_text == *"-O"* ]] || undocumented="$undocumented $flag"
    elif ! printf '%s\n' "$help_text" |
           grep -qE "(^|[[:space:],])$flag([[:space:],]|\$)"; then
      undocumented="$undocumented $flag"
    fi
  done < <(sed -n '/^while \[\[ \$# -gt 0 \]\]/,/^done$/p' "$driver" |
           sed -n 's/^ *\(-[^)]*\)).*/\1/p' | tr '|' '\n' |
           sed 's/^ *//; s/ *$//' | grep -v '\*' | sort -u)
  if [[ -n $undocumented ]]; then
    echo "--- help: pascalcc accepts options --help does not mention:$undocumented ---" >&2
    failed=$((failed + 1))
  fi
fi

# --- and that --target= picks the machine the module says it is for ---------
#
# ADR-0156. `clang` overrides both header lines with its own target's, so what
# these check is the module as a *document*: what `llc` with no -mtriple reads,
# and what a person reads. Two directions, because the flag is as much about
# what it refuses -- a target whose layout has not been compared against LlSize
# and LlAlign is answered wrongly rather than refused if this arm goes.
cat >"$work/target.pas" <<'PAS'
program Target(output);
begin
  writeln('x')
end.
PAS

checked=$((checked + 1))
if "$pascalc" --target=aarch64-linux-gnu "$work/target.pas" \
     -o "$work/target.ll" >/dev/null 2>&1 &&
   grep -q 'target triple = "aarch64-unknown-linux-gnu"' "$work/target.ll" &&
   grep -q 'i8:8:32-i16:16:32' "$work/target.ll"; then
  :
else
  echo "--- target: --target=aarch64-linux-gnu did not emit that target ---" >&2
  failed=$((failed + 1))
fi

# --- and that the driver hands a dump through untouched ---------------------
#
# ADR-0239. A --dump flag asks the *compiler* a question and the answer is its
# standard output, so `tools/pascalcc` has nothing to add: no assembling, no
# linking, and no folding the answer into stderr the way it folds a
# diagnostic. Until the language server asked for one the driver had never
# been handed a dump at all, and it answered `pascalcc: unknown option
# '--dump-symbols'` -- on stderr, to a caller reading stdout, which is an
# empty outline and no complaint anywhere.
#
# It is checked here rather than by the dump corpus because `tests/dumps` is
# handed `pascalc` and this is a claim about the *driver*: which is what this
# harness is for, the build wiring rather than the compiler.
checked=$((checked + 1))
dump_out=$(PASCALC=$pascalc "$driver" --dump-symbols "$work/target.pas" \
             -o "$work/target.ll" 2>"$work/dump.err")
if [[ $dump_out != "symbol 0 program 1 9 6 4 4 target" ]]; then
  echo "--- dump: pascalcc --dump-symbols did not pass the dump through ---" >&2
  echo "wrote: $dump_out" >&2
  cat "$work/dump.err" >&2
  failed=$((failed + 1))
fi

# --- and that there is no standard to select ---------------------------------
#
# ADR-0232 removed `--std` and with it the two conformance modes, so there is
# one language and the compiler has no mode to be put into. Three claims, and
# each fails in a different direction.
#
# First, that the flag is gone from the compiler rather than quietly accepted:
# a `--std=iso7185` that was ignored would compile an ISO 7185 program under
# the dialect and say nothing, which is the outcome a caller has no way to
# notice. The line above it -- ADR-0165's default -- is what this replaces, and
# it was pinned here because two harnesses had been riding on the default
# silently.
checked=$((checked + 1))
cat >"$work/dflt.pas" <<'PAS'
program dflt(output);
var s: string(5);
begin s := 'hi'; writeln(s) end.
PAS
if "$pascalc" --std=extended "$work/dflt.pas" -o /dev/null >"$work/std.txt" 2>&1
then
  echo "--- std: pascalc still accepts --std= ---" >&2
  failed=$((failed + 1))
elif ! grep -q "unknown option" "$work/std.txt"; then
  echo "--- std: --std= was refused without naming why ---" >&2
  cat "$work/std.txt" >&2
  failed=$((failed + 1))
fi

# Second, that an unflagged source is the whole language. `string(n)` is the
# cheapest construct ISO 7185 does not have, and it is what the check this
# replaces used to prove the default was Extended Pascal; it now proves there
# is nothing left to select.
checked=$((checked + 1))
if ! "$pascalc" "$work/dflt.pas" -o "$work/dflt.ll" >/dev/null 2>&1; then
  echo "--- std: the compiler no longer accepts string(n) unflagged ---" >&2
  failed=$((failed + 1))
fi

# Third, that the *driver* still swallows the flag. `pascalcc --std=` is
# accepted and ignored on purpose (ADR-0232), so a caller's build script
# survives the release that removed it -- and a driver that passed it through
# to a compiler which no longer knows it would break exactly the scripts that
# arm was written for.
checked=$((checked + 1))
if ! PASCALC=$pascalc AFTERSCHOOL_PASCAL_RUNTIME=$runtime \
     "$root/tools/pascalcc" -S --std=iso7185 "$work/dflt.pas" \
     -o "$work/dflt.ll" >"$work/std.txt" 2>&1; then
  echo "--- std: pascalcc no longer accepts and ignores --std= ---" >&2
  cat "$work/std.txt" >&2
  failed=$((failed + 1))
fi

# ADR-0210: a diagnostic about an imported component names *that component*.
# Nothing under tests/ can assert this, and for a sharp reason:
# run_test.sh translates every .components entry separately and
# first, and gives up if one fails -- so no case can reach a component that
# does not translate on its own being handed to --import anyway. A person
# reaches it by typing it. tests/checks/importdiag/ has the two sources.
diag="$root/tests/checks/importdiag"

# The component's error carries the component's name. It used to carry the
# client's, with the component's line number -- client.pas is three lines long
# and the error was reported at line 12 of it.
checked=$((checked + 1))
if "$pascalc" --import "$diag/badmod.pas" "$diag/client.pas" \
     -o /dev/null >"$work/diag.txt" 2>&1; then
  echo "--- importdiag: a component with a type error was accepted ---" >&2
  failed=$((failed + 1))
elif ! grep -q "badmod.pas:15:" "$work/diag.txt"; then
  echo "--- importdiag: an imported component's error did not name it ---" >&2
  cat "$work/diag.txt" >&2
  failed=$((failed + 1))
fi

# And the other direction, which is what stops "name the component for
# everything" from passing: the client's own error still names the client.
checked=$((checked + 1))
if "$pascalc" --import "$diag/badmod.pas" "$diag/badclient.pas" \
     -o /dev/null >"$work/diag.txt" 2>&1; then
  echo "--- importdiag: a client with a type error was accepted ---" >&2
  failed=$((failed + 1))
elif ! grep -q "badclient.pas:3:" "$work/diag.txt"; then
  echo "--- importdiag: the client's own error did not name the client ---" >&2
  cat "$work/diag.txt" >&2
  failed=$((failed + 1))
fi

# The default has to stay the default: this repository is built and tested on
# x86-64 and the seed was generated for it.
checked=$((checked + 1))
if "$pascalc" "$work/target.pas" -o "$work/host.ll" >/dev/null 2>&1 &&
   grep -q 'target triple = "x86_64-pc-linux-gnu"' "$work/host.ll"; then
  :
else
  echo "--- target: the default is no longer x86_64-pc-linux-gnu ---" >&2
  failed=$((failed + 1))
fi

checked=$((checked + 1))
if "$pascalc" --target=riscv64-linux-gnu "$work/target.pas" -o /dev/null \
     >"$work/target.txt" 2>&1; then
  echo "--- target: an unverified target was accepted ---" >&2
  failed=$((failed + 1))
elif ! grep -q 'unknown target' "$work/target.txt" ||
     ! grep -q 'x86_64-pc-linux-gnu' "$work/target.txt"; then
  echo "--- target: the refusal does not name what is admitted ---" >&2
  cat "$work/target.txt" >&2
  failed=$((failed + 1))
fi

# --- and that it says so when it does not translate something ---------------
#
# A compiler that cannot report failure is not usable from a build rule:
# `pascalc bad.pas && clang bad.ll ...` would run the linker on a file that was
# never written. ISO/IEC 10206:1991 §6.7.5.7's `halt` takes no parameters and
# neither standard models an exit status, so this is the one language extension
# this processor adds for its own sake (ADR-0084) -- and *nothing else checks
# it*. Removing `halt(1)` from compiler.pas passed all 279 cases, the golden
# files comparing what a program wrote and never how it stopped.
cat >"$work/rejected.pas" <<'PAS'
program Rejected(output);
begin
  undeclared := 1
end.
PAS
: >"$work/ir.ll"
"$pascalc" "$work/rejected.pas" -o "$work/ir.ll" >"$work/rej.txt" 2>&1
status=$?
checked=$((checked + 1))
if [[ $status -eq 0 ]]; then
  echo "--- rejected: pascalc exited 0 for a program it refused ---" >&2
  failed=$((failed + 1))
elif [[ -s $work/ir.ll ]]; then
  echo "--- rejected: pascalc wrote IR for a program it refused ---" >&2
  failed=$((failed + 1))
elif ! grep -q "undeclared identifier" "$work/rej.txt"; then
  echo "--- rejected: pascalc gave no diagnostic naming the fault ---" >&2
  cat "$work/rej.txt" >&2
  failed=$((failed + 1))
fi

# The other half of the same contract: a successful run must exit 0, or a build
# rule would stop on every program it compiled.
"$pascalc" "$root/tests/hello.pas" -o "$work/ir.ll" >/dev/null 2>&1
status=$?
checked=$((checked + 1))
if [[ $status -ne 0 ]]; then
  echo "--- accepted: pascalc exited $status for a program it translated ---" >&2
  failed=$((failed + 1))
fi

# --- AFTERSCHOOL_PASCAL_TARGET, and that an explicit flag beats it -----------
#
# ADR-0159 added the variable so a whole run -- the arm64 CI job, above all --
# can be pointed at one target without a flag on every invocation. Nothing here
# exercised it: the only thing that set it was that job, so a typo in
# tools/pascalcc would have passed every local gate and failed remotely, on
# another architecture, in a job about something else. The precedence rule was
# asserted by nothing at all.
#
# Both halves, because a check that only pins the variable passes just as well
# with the explicit flag ignored.
target_check() { # <expected triple> <env value> <extra args...>
  local want=$1 env=$2; shift 2
  checked=$((checked + 1))
  if ! AFTERSCHOOL_PASCAL_TARGET=$env PASCALC=$pascalc \
       AFTERSCHOOL_PASCAL_RUNTIME=$runtime \
       "$driver" -S "$@" "$work/target.pas" -o "$work/t.ll" >/dev/null 2>&1
  then
    echo "--- target: pascalcc failed with AFTERSCHOOL_PASCAL_TARGET=$env ---" >&2
    failed=$((failed + 1))
  elif ! grep -q "target triple = \"$want\"" "$work/t.ll"; then
    echo "--- target: AFTERSCHOOL_PASCAL_TARGET=$env $* did not emit $want ---" >&2
    grep -m1 'target triple' "$work/t.ll" >&2
    failed=$((failed + 1))
  fi
}
target_check aarch64-unknown-linux-gnu aarch64-linux-gnu
target_check x86_64-pc-linux-gnu       aarch64-linux-gnu --target=x86_64-pc-linux-gnu

# --- a misused command line is reported, and reported as a failure ----------
#
# The command line is part of the interface (CHANGELOG says so in as many
# words), and none of it was tested. It could not be: these messages carry the
# `pascalc: ` prefix, which tests/checks/diagnostic_coverage.py filters out as
# driver output rather than a diagnostic about a program -- so the one gate
# that counts messages is blind to them by construction, and
# tests/checks/line_coverage.py is what found the branches unrun (ADR-0104).
#
# Each case asserts the message *and* a non-zero exit, for the reason the
# rejected-program check above gives: a driver that misreports a bad flag as
# success is worse than one that says nothing.
cli_check() { # <expected substring> <args...>
  local want=$1; shift
  checked=$((checked + 1))
  "$pascalc" "$@" >"$work/cli.txt" 2>&1
  local st=$?
  if [[ $st -eq 0 ]]; then
    echo "--- cli: '$*' exited 0 ---" >&2
    failed=$((failed + 1))
  elif ! grep -qF -- "$want" "$work/cli.txt"; then
    echo "--- cli: '$*' did not report '$want' ---" >&2
    cat "$work/cli.txt" >&2
    failed=$((failed + 1))
  fi
}
cli_check "unknown option"            --no-such-flag "$root/tests/hello.pas"
cli_check "-o needs a file name"      "$root/tests/hello.pas" -o
cli_check "--import needs a file name" "$root/tests/hello.pas" --import
cli_check "more than one input file"  "$root/tests/hello.pas" "$root/tests/arith.pas"
# A command line one word longer than the program-parameter list. Nothing can
# count the arguments -- an unbound program-parameter is the only end-of-list
# there is -- so this is reported by one *extra* parameter being bound, and
# without it the surplus was silently dropped: twelve was exactly what
# tests/dialect/lib_os.pas needs, so ADR-0156's --target= made a correct
# command line report "-o needs a file name" about the argument that fell off
# the end. The complaint has to name the length, not the last flag standing.
long_args=()
for _ in $(seq 70); do long_args+=(--dump-limits); done
cli_check "more than 72 arguments" "${long_args[@]}" "$root/tests/hello.pas" \
          -o "$work/ir.ll"

# ...and the length below that is accepted, which is the half a bound-raising
# change gets wrong: a check that only pins the refusal passes just as well
# with the bound left where it was.
checked=$((checked + 1))
ok_args=()
for _ in $(seq 69); do ok_args+=(--dump-limits); done
if ! "$pascalc" "${ok_args[@]}" "$root/tests/hello.pas" -o "$work/long.ll" \
     >"$work/long.txt" 2>&1 || [[ ! -s $work/long.ll ]]; then
  echo "--- cli: 24 arguments were refused or wrote no IR ---" >&2
  cat "$work/long.txt" >&2
  failed=$((failed + 1))
fi
# With no source at all pascalc writes the usage rather than a message, which
# is the one case here that is not a complaint -- and worth pinning, because
# "prints help" and "silently succeeds" are indistinguishable without the exit
# status this function also checks.
cli_check "usage: pascalc"            -o "$work/ir.ll"

if [[ $failed -ne 0 ]]; then
  echo "producttest: $failed of $((checked + failed)) failed" >&2
  exit 1
fi
echo "producttest: $checked checks passed against the built pascalc"
