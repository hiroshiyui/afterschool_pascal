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
# `pascalc` is `selfhost/compiler.pas` translated by `pascalc-s0` and linked by
# CMake, and until this existed nothing tested that artefact. `irtest.sh` looks
# thorough enough to cover it and does not: it builds a stage-1 compiler of its
# own in a temporary directory, so the binary in `build/bin` could be missing,
# stale or built from the wrong source and every test would stay green. What is
# checked here is the *build wiring* -- that the product exists, runs, and
# compiles a program correctly -- rather than the compiler, which the 276 cases
# and the stage-2/stage-3 fixed point already cover.
#
# It is deliberately small for that reason. Two programs, one per standard,
# because --std is part of the interface being checked.
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

# The default pair covers one program per standard. A caller may name others.
if [[ $# -gt 0 ]]; then
  files=("$@")
else
  files=("$root/tests/hello.pas" "$root/tests/extended/otherwise.pas")
fi

# Which standard a source is written in is decided by where it lives, exactly
# as in run_test.sh, difftest.sh and irtest.sh -- so the four harnesses cannot
# be told different things about one file. Unanchored on purpose (ADR-0034).
standard_of() {
  # A source outside tests/extended/ may still be Extended Pascal, and says so
  # with a `name.std` file beside it holding one word -- the same sidecar
  # convention as `name.in`, `name.epoch` and `name.components`. It exists
  # because selfhost/compiler.pas is Extended Pascal and does not live in the
  # directory that would otherwise be the only way to say so (ADR-0033).
  local sidecar="${1%.pas}.std"
  if [[ -f $sidecar ]]; then
    tr -d '[:space:]' <"$sidecar"
    echo
    return
  fi
  case $1 in
    *tests/extended/*)  echo extended ;;
    *)                  echo iso7185 ;;
  esac
}

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
  # through the binding of its program-parameters, so --std and -o are flags
  # like any other compiler's rather than the files they used to be.
  if ! timeout 120 "$pascalc" "--std=$(standard_of "$f")" "$f" \
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
#
# --std= is the one flag whose accepted spellings are the whole word
# (--std=iso7185, --std=extended) while the help text writes the placeholder
# form, so it is matched by its prefix.
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
    [[ $flag == --std=* ]] && probe="--std="
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
# Two arms are written as a family rather than as themselves, in the help text
# and in the parser both, so they are matched by the prefix they share:
# `--std=*` against `--std=` as the check above does it, and `-O0|-O1|-O2|-O3`
# against `-O`, which the text spells `-O0 .. -O3`. The catch-all arms (`-*`,
# `*.o`, `*`) name no option and are dropped.
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
    if [[ $flag == --std=* ]]; then
      found=$help_text; probe="--std="
      [[ $found == *"$probe"* ]] || undocumented="$undocumented $flag"
    elif [[ $flag == -O[0-9] ]]; then
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
for _ in $(seq 22); do long_args+=(--std=iso7185); done
cli_check "more than 24 arguments" "${long_args[@]}" "$root/tests/hello.pas" \
          -o "$work/ir.ll"

# ...and the length below that is accepted, which is the half a bound-raising
# change gets wrong: a check that only pins the refusal passes just as well
# with the bound left where it was.
checked=$((checked + 1))
ok_args=()
for _ in $(seq 21); do ok_args+=(--std=iso7185); done
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
