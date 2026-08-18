#!/usr/bin/env bash
# Differential test: a stage-1 component against the stage-0 one it was ported
# from, on every Pascal source in the repository.
#
#   difftest.sh <path-to-pascalc-s0> <path-to-pascalc> [files...]
#
# The roadmap makes this the checkpoint that comes *before* stage 1 is declared
# working. A disagreement here is a bug in one of the two implementations,
# found on a file small enough to bisect; the same bug found at stage 3 is a
# byte mismatch between two compiler binaries with nothing to compare but their
# output.
#
# Both sides write the same format — `pascalc-s0 --dump-all` against
# selfhost/compiler.pas — so the comparison is a plain diff. ISO 7185 has no
# include mechanism, so the Pascal side is one program covering every stage
# ported so far, and it dumps all of them in one pass; there is no mode to
# select because there is no separate binary to select it on.
#
# The Pascal side is itself compiled by the compiler under test, so this also
# checks that the compiler can still build a program of that size and shape.
set -u

pascalc=$1
shift || { echo "usage: difftest.sh <pascalc-s0> <pascalc> [files...]" >&2; exit 2; }
stage1=$1
shift || { echo "usage: difftest.sh <pascalc-s0> <pascalc> [files...]" >&2; exit 2; }

component=compiler
flag=--dump-all
what="stage for stage"

here=$(cd "$(dirname "$0")" && pwd)
root=$(dirname "$here")
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# Which standard a source is written in is decided by where it lives:
# tests/extended/ is ISO/IEC 10206:1991, everything else is ISO 7185. Both
# compilers are told from the same variable so they cannot drift — the C++ one
# by --std, the Pascal one through a file, because ISO 7185 gives a program no
# other channel (ADR-0033).
# The glob is deliberately unanchored: a file named on the command line arrives
# as a relative path, and a leading-slash pattern would quietly call it ISO 7185
# and compare two identical rejections.
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
    # The dialect (ADR-0117). Same construction as the line above, and the
    # glob is unanchored for the same reason: a relative path named on the
    # command line must not fall through to iso7185.
    *tests/dialect/*)   echo afterschool ;;
    *)                  echo iso7185 ;;
  esac
}

# The Pascal compiler is *given*, not built here. Until ADR-0085 stage 0 built
# it, which is why this script used to take one binary; since ADR-0108 stage 0
# is a front end that generates no code, and the seed is what builds the
# compiler (ADR-0083). So both sides arrive already built and this script only
# compares them.

if [[ $# -gt 0 ]]; then
  files=("$@")
else
  # Every Pascal source in the tree, the stage-1 sources included: they are the
  # largest and most varied Pascal in the repository, and the shape the rest of
  # the port will take.
  #
  # lib/ is the standard library (ADR-0114) and is walked for the same reason as
  # everything else: it is ordinary Extended Pascal, and a front end that read
  # it differently would be a front-end bug found on a small file. Each module
  # there carries a `name.std` sidecar, because standard_of() decides from the
  # path and lib/ is not tests/extended/ -- the same reason
  # selfhost/compiler.std exists.
  #
  # tests/checks/difftest_check.py globs these same three directories and
  # requires the count to match. Changing one without the other is what that
  # check is for.
  mapfile -t files < <(find "$root/tests" "$root/lib" "$here" -name '*.pas' | sort)
fi

if [[ ${#files[@]} -eq 0 ]]; then
  echo "differential $component test: no files to compare" >&2
  exit 1
fi


# Where a machine-readable list of the disagreeing files goes, if anything asked
# for one. tests/checks/difftest_check.py is what asks: the set of files that
# disagree is a *baseline* that may shrink and may not grow, so what it needs is
# which files, not how many -- the same reason line_coverage.txt records the
# per-procedure breakdown rather than only a count.
list_out=${DIFFTEST_LIST:-}
: >"${list_out:-/dev/null}"

note_differs() {
  [[ -n $list_out ]] && printf '%s\n' "${1#"$root/"}" >>"$list_out"
  return 0
}

checked=0
failed=0
skipped=0
for f in "${files[@]}"; do
  standard=$(standard_of "$f")
  # The dialect has no second implementation and will not get one: ADR-0117
  # freezes the reference front end at the conformance surface, because a
  # front-end feature shipping twice is the cost ADR-0085 retired stage 0 to
  # escape.
  #
  # So a dialect source is *skipped* rather than compiled under --std=extended.
  # Handing it to a front end that does not know the mode would compare two
  # rejections, which are equal, and pass -- ADR-0034's trap exactly, and the
  # reason that glob is unanchored.
  #
  # Skipped files are counted and reported, not dropped. difftest_check.py
  # requires compared + skipped to equal the corpus, so a file cannot leave the
  # comparison without something saying so.
  if [[ $standard == afterschool ]]; then
    skipped=$((skipped + 1))
    continue
  fi
  "$pascalc" "--std=$standard" "$flag" "$f" >"$work/cpp.txt" 2>"$work/cpp.err"
  # A bug can be a *loop* rather than a wrong answer — a scanner that
  # recognises no character consumes none and never advances. That is a
  # failure like any other, so it is bounded here instead of hanging the run.
  # The second argument is where the Pascal compiler writes its IR. Nothing
  # here compares it -- selfhost/irtest.sh is what runs it -- but generating
  # it on every file is free coverage: a code generator that crashes or
  # loops on a corpus file fails here, on the file that did it.
  # --dump-all on both sides: the dumps are what this compares, and they are
  # opt-in on the Pascal side since it grew a compiler's ordinary quiet-on-
  # success behaviour. The IR is still written, which is what keeps the code
  # generator exercised on every file here even though none of it is compared.
  timeout 120 "$stage1" "--std=$standard" --dump-all "$f" \
    -o "$work/ir.ll" >"$work/pas.txt" 2>"$work/pas.err"
  status=$?
  checked=$((checked + 1))
  if [[ $status -eq 124 ]]; then
    echo "--- $(basename "$f"): the Pascal $component did not terminate ---" >&2
    note_differs "$f"
    failed=$((failed + 1))
    continue
  fi
  # 1 is a *rejection*, not a crash: since ADR-0084 the Pascal compiler reports
  # the outcome the way the C++ one always has, and a large part of this corpus
  # -- badparse/, badsema/, torture.pas and every tests/*.err case -- is meant
  # to be rejected. The dumps are what decide whether the two agree about it,
  # and they are compared below either way. Anything else is a crash.
  if [[ $status -ne 0 && $status -ne 1 ]]; then
    echo "--- $(basename "$f"): the Pascal $component exited with $status ---" >&2
    cat "$work/pas.err" >&2
    note_differs "$f"
    failed=$((failed + 1))
    continue
  fi
  # An empty dump on both sides would compare equal while proving nothing, and
  # every file in the corpus produces either a tree or a diagnostic.
  if [[ ! -s "$work/cpp.txt" ]]; then
    echo "--- $(basename "$f"): the C++ $component produced nothing to compare ---" >&2
    cat "$work/cpp.err" >&2
    note_differs "$f"
    failed=$((failed + 1))
    continue
  fi
  if ! diff -u --label "cpp/$(basename "$f")" --label "pascal/$(basename "$f")" \
          "$work/cpp.txt" "$work/pas.txt" >"$work/delta"; then
    echo "--- $(basename "$f"): the two ${component}s disagree ---" >&2
    head -40 "$work/delta" >&2
    note_differs "$f"
    failed=$((failed + 1))
  fi
done

# How many files were compared, in a fixed form and on every path -- the
# summary lines below say it too, but one of them goes to stderr and they word
# it differently, so neither is something another program should read.
#
# tests/checks/difftest_check.py is what reads this, and it is the denominator
# the baseline could not carry: the baseline records *which* files disagree, so
# a run that compared far fewer files and found no disagreement among them was
# indistinguishable from a clean one. `find` matching one directory less is all
# that would take.
echo "difftest-compared: $checked"
# Reported on its own line and in the same fixed form, because a skip is the
# one way a file leaves this comparison and "no disagreements" must not be
# able to mean "nothing was looked at".
echo "difftest-skipped: $skipped"

if [[ $failed -ne 0 ]]; then
  echo "differential $component test: $failed of $checked files disagree" >&2
  exit 1
fi

if [[ $skipped -ne 0 ]]; then
  echo "differential $component test: $checked files, both ${component}s agree" \
       "$what ($skipped dialect source(s) skipped: no second implementation)"
else
  echo "differential $component test: $checked files, both ${component}s agree $what"
fi
