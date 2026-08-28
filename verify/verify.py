#!/usr/bin/env python3
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

"""Formal verification of Afterschool Pascal's lowering rules.

Two halves, and neither is sufficient alone:

  --prove       Ask Z3 whether any input makes a lowering disagree with the ISO
                specification. `unsat` on the negated claim means the rule holds
                for all 2^64 inputs — the thing testing cannot establish.

  --crosscheck  Compile and run a real Pascal program with the real compiler at
                the adversarial points, and compare against the specification
                computed independently in Python.

The proof half reasons about `lowering.py`, which is a hand-written model of
CodeGen -- of `selfhost/compiler.pas` since ADR-0085, and of the C++ one
before it, which is a file that no longer exists. That model can drift from the
compiler, and a proof about a stale
model is worse than no proof because it is reassuring. The cross-check is what
detects the drift: it runs the actual binary. Treat a cross-check failure as
evidence that the model is lying, not merely that a test broke.

Compiling at both -O0 and -O2 is deliberate: a disagreement between them is the
signature of undefined behaviour in the emitted IR being exploited by the
optimiser.

Exit status: 0 all good, 1 a rule or cross-check failed, 77 skipped (no z3).
"""

import argparse
import os
import subprocess
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

try:
    import z3
except ImportError:
    print("verify: z3 is not installed (pip install z3-solver) — skipping")
    sys.exit(77)

import iso  # noqa: E402  (import after the z3 availability check)
import rules as catalogue  # noqa: E402


GREEN, RED, YELLOW, DIM, RESET = (
    "\033[32m", "\033[31m", "\033[33m", "\033[2m", "\033[0m"
) if sys.stdout.isatty() else ("", "", "", "", "")


# ------------------------------------------------------------------ proving


def prove_at(rule, width, timeout_ms):
    """Return (ok, detail). A rule holds when its negation is unsatisfiable."""
    precondition, claim = rule.build(width)
    solver = z3.Solver()
    solver.set("timeout", timeout_ms)
    solver.add(precondition)
    solver.add(z3.Not(claim))

    result = solver.check()
    if result == z3.unsat:
        return True, "no counterexample exists"
    if result == z3.unknown:
        return False, f"solver returned unknown ({solver.reason_unknown()})"
    model = solver.model()
    assignment = ", ".join(
        f"{d.name()} = {model[d]}"
        for d in sorted(model.decls(), key=lambda d: d.name())
        if not d.name().startswith("witness_"))
    return False, f"counterexample: {assignment or '(trivially false)'}"


def prove(rule, timeout_ms):
    """Check a rule at every width it declares; the first disagreement wins."""
    for width in rule.widths:
        holds, detail = prove_at(rule, width, timeout_ms)
        if not holds:
            label = detail if len(rule.widths) == 1 else f"at {width} bits, {detail}"
            return False, label
    return True, "no counterexample exists"


def run_proofs(timeout_ms):
    print("Proving lowering rules with Z3\n")
    failures = []

    for rule in catalogue.ALL:
        holds, detail = prove(rule, timeout_ms)
        expected_to_hold = rule.status == catalogue.MUST_HOLD
        scope = ("all 32-bit inputs" if not rule.bounded else
                 "widths " + ",".join(str(w) for w in rule.widths))

        if holds == expected_to_hold:
            if expected_to_hold:
                mark = f"{GREEN}proved{RESET}  " if not rule.bounded else \
                       f"{GREEN}proved{RESET}* "
                print(f"  {mark} {rule.name}")
                print(f"           {DIM}{scope}{RESET}")
            else:
                # A known gap that still fails to hold: the documented
                # counterexample is still there, which is what we expect.
                print(f"  {YELLOW}gap{RESET}      {rule.name}")
                print(f"           {DIM}{detail}{RESET}")
                if rule.note:
                    print(f"           {DIM}{rule.note}{RESET}")
        elif expected_to_hold:
            print(f"  {RED}FAILED{RESET}   {rule.name}")
            print(f"           {rule.iso_ref}")
            print(f"           {rule.source}")
            print(f"           {detail}")
            failures.append(rule.name)
        else:
            print(f"  {RED}STALE{RESET}    {rule.name}")
            print("           this known gap now holds — the compiler was "
                  "fixed and the catalogue needs updating")
            failures.append(rule.name)

    proved = sum(1 for r in catalogue.ALL if r.status == catalogue.MUST_HOLD)
    bounded = sum(1 for r in catalogue.ALL
                  if r.status == catalogue.MUST_HOLD and r.bounded)
    gaps = sum(1 for r in catalogue.ALL if r.status == catalogue.KNOWN_GAP)
    wide = sum(1 for r in catalogue.ALL
               if r.status == catalogue.MUST_HOLD and 64 in r.widths)
    print(f"\n  {proved} rules claimed correct "
          f"({proved - bounded} at full width, {wide} of them at 64 bits too "
          f"for ADR-0128's int64, {bounded} bounded), "
          f"{gaps} known gaps documented")
    if bounded:
        print(f"  {DIM}* bounded: the claim is checked at reduced widths, "
              f"because at the real width\n"
              f"    it bit-blasts into a circuit too large to solve — a "
              f"symbolic division or\n"
              f"    multiplication over 32 bits, or a symbolic shift over the "
              f"256 bits of a set.\n"
              f"    It is established exhaustively at small widths "
              f"instead. The lowering is the\n"
              f"    same instruction sequence at every width, which is the "
              f"argument for\n"
              f"    generalising — but it is an argument, not a "
              f"proof.{RESET}")
    return failures


# -------------------------------------------------------------- cross-check

# Adversarial points: sign combinations, the boundaries of the Pascal integer
# range, and the cases where truncating and flooring division disagree. The
# INT_MIN cases are deliberately absent — they are known gaps (see the
# catalogue), and a cross-check is only meaningful where behaviour is defined.
DIV_MOD_POINTS = [
    (-7, 3), (7, 3), (-1, 7), (1, 7), (0, 5), (-9, 3), (9, 3),
    (2147483647, 2), (-2147483647, 3), (7, 7), (1, 2147483647),
]
ODD_POINTS = [-3, -4, 0, 1, 2147483647, -2147483647]
# Both ends of the index range, both sides of zero, and zero itself.
INDEX_POINTS = [-3, -2, -1, 0, 1, 2, 3]


def iso_div(i, j):
    """Truncating division, stated independently of the compiler."""
    q = abs(i) // abs(j)
    return q if (i >= 0) == (j >= 0) else -q


def iso_mod(i, j):
    """The unique r with 0 <= r < j and j | (i - r); j > 0 only."""
    assert j > 0
    return i - j * (i // j)


def build_crosscheck_program():
    # The array is indexed from a negative lower bound so that the offset
    # subtraction the index rules are about is actually exercised: with a lower
    # bound of 1 a wrong `i - lo` is off by a constant and easy to miss.
    lines = ["program Crosscheck(output);",
             "type colour = (red, green, blue);",
             "     link = ^cell;",
             "     cell = record datum: integer; next: link end;",
             "var i, j: integer;",
             "    a: array [-3..3] of integer;",
             "    c: colour;",
             "    d: 1..9;",
             "    head, p: link;",
             "begin"]
    expected = []

    for i, j in DIV_MOD_POINTS:
        lines.append(f"  i := {i}; j := {j};")
        lines.append("  writeln(i div j);")
        expected.append(str(iso_div(i, j)))
        if j > 0:
            lines.append("  writeln(i mod j);")
            expected.append(str(iso_mod(i, j)))

    for i in ODD_POINTS:
        lines.append(f"  i := {i};")
        lines.append("  writeln(odd(i));")
        expected.append("TRUE" if i % 2 != 0 else "FALSE")

    # ord/chr round trip and ordinal comparison
    lines.append("  writeln(ord('A'));")
    expected.append("65")
    lines.append("  writeln(chr(ord('A')));")
    expected.append("A")
    lines.append("  writeln('a' < 'b');")
    expected.append("TRUE")

    # Every element of an array whose bounds straddle zero, written through one
    # index expression and read back through another.
    lines.append("  for i := -3 to 3 do a[i] := i * i;")
    for k in INDEX_POINTS:
        lines.append(f"  i := {k}; writeln(a[i]);")
        expected.append(str(k * k))

    # An enumeration's ordinals, its ordering, and succ/pred at both ends of
    # the range that exists — the places the generalised bounds are load-bearing.
    lines.append("  for c := red to blue do write(ord(c));")
    lines.append("  writeln;")
    expected.append("012")
    lines.append("  writeln(succ(red) = green, pred(blue) = green, red < blue);")
    expected.append("TRUETRUETRUE")

    # A subrange accepts its own bounds and every value between them.
    lines.append("  j := 0;")
    lines.append("  for i := 1 to 9 do begin d := i; j := j + ord(d) end;")
    lines.append("  writeln(j);")
    expected.append("45")

    # §6.7.1's substitution, which is what decides where succ and pred run out
    # and is the one thing the enumeration lines above cannot show: an
    # enumeration is its own base, so it ends where it is written to end, and
    # the two readings agree. A subrange's do not. `succ` of a 1..9 holding 9
    # is 10 because §6.7.1 treats the factor as an integer, and a compiler that
    # trapped at the subrange's own end would stop this program rather than
    # print anything — which is what makes this line tie `succ_traps_at`'s
    # `end` to what the compiler actually compares against.
    lines.append("  d := 9; i := succ(d);")
    lines.append("  d := 1; j := pred(d);")
    lines.append("  writeln(i, ' ', j);")
    expected.append("10 0")

    # Every arm of a case, selected in turn.
    lines.append("  for i := 1 to 4 do")
    lines.append("    case i of")
    lines.append("      1: write('a');")
    lines.append("      2, 3: write('b');")
    lines.append("      4: write('c')")
    lines.append("    end;")
    lines.append("  writeln;")
    expected.append("abbc")

    # A heap-allocated list, walked and given back. There is no SMT rule for
    # any of this — see ADR-0019 on why — so the cross-check is the whole of
    # what the verifier says about pointers.
    lines.append("  head := nil; j := 0;")
    lines.append("  for i := 1 to 5 do")
    lines.append("    begin new(p); p^.datum := i * i; p^.next := head;")
    lines.append("          head := p end;")
    lines.append("  p := head;")
    lines.append("  while p <> nil do begin j := j + p^.datum; p := p^.next end;")
    lines.append("  writeln(j);")
    expected.append(str(sum(i * i for i in range(1, 6))))
    lines.append("  while head <> nil do")
    lines.append("    begin p := head; head := head^.next; dispose(p) end;")
    lines.append("  writeln(head = nil);")
    expected.append("TRUE")

    lines.append("end.")
    return "\n".join(lines) + "\n", expected


def run_crosscheck(pascalc):
    print("\nCross-checking the real compiler at the adversarial points\n")
    if not os.path.exists(pascalc):
        print(f"  {RED}FAILED{RESET}   compiler not found: {pascalc}")
        return ["compiler-missing"]

    source, expected = build_crosscheck_program()
    failures = []

    with tempfile.TemporaryDirectory() as work:
        src = os.path.join(work, "crosscheck.pas")
        with open(src, "w") as f:
            f.write(source)

        outputs = {}
        for opt in ("-O0", "-O2"):
            exe = os.path.join(work, f"crosscheck{opt}")
            # No --std=: ADR-0232 removed the modes. This used to pass
            # --std=iso7185 explicitly, because the generated program had a
            # field called `value` and Extended Pascal reserves that spelling
            # -- the field is `datum` now, which is the cost that decision was
            # taken with, met here as it is met in the corpus.
            built = subprocess.run([pascalc, opt, src, "-o", exe],
                                   capture_output=True, text=True)
            if built.returncode != 0:
                print(f"  {RED}FAILED{RESET}   compilation at {opt}")
                print(f"           {built.stderr.strip()}")
                failures.append(f"compile{opt}")
                continue

            ran = subprocess.run([exe], capture_output=True, text=True)
            if ran.returncode != 0:
                print(f"  {RED}FAILED{RESET}   the program exited "
                      f"{ran.returncode} at {opt}")
                failures.append(f"run{opt}")
                continue

            actual = ran.stdout.splitlines()
            outputs[opt] = actual

            mismatches = [
                (n, want, got)
                for n, (want, got) in enumerate(zip(expected, actual), 1)
                if want != got
            ]
            if len(actual) != len(expected):
                print(f"  {RED}FAILED{RESET}   {opt}: expected "
                      f"{len(expected)} lines, got {len(actual)}")
                failures.append(f"length{opt}")
            elif mismatches:
                print(f"  {RED}FAILED{RESET}   {opt}: "
                      f"{len(mismatches)} value(s) disagree with the spec")
                for n, want, got in mismatches[:5]:
                    print(f"           line {n}: expected {want}, got {got}")
                failures.append(f"values{opt}")
            else:
                print(f"  {GREEN}matches{RESET}  {opt}: all "
                      f"{len(expected)} values agree with the specification")

        if len(outputs) == 2 and outputs["-O0"] != outputs["-O2"]:
            print(f"  {RED}FAILED{RESET}   -O0 and -O2 disagree — the "
                  "signature of undefined behaviour in the emitted IR")
            failures.append("opt-divergence")
        elif len(outputs) == 2:
            print(f"  {GREEN}matches{RESET}  -O0 and -O2 agree")

    return failures


# -------------------------------------------------------------------- main


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pascalc", default="tools/pascalcc",
                        help="the compiler under test; tools/pascalcc by default, which is pascalc plus the linking clang cannot be asked of a Pascal program")
    parser.add_argument("--prove", action="store_true")
    parser.add_argument("--crosscheck", action="store_true")
    parser.add_argument("--timeout", type=int, default=30000,
                        help="per-rule solver timeout in milliseconds")
    args = parser.parse_args()

    # Default to doing both; either flag narrows it.
    do_prove = args.prove or not args.crosscheck
    do_crosscheck = args.crosscheck or not args.prove

    failures = []
    if do_prove:
        failures += run_proofs(args.timeout)
    if do_crosscheck:
        failures += run_crosscheck(args.pascalc)

    print()
    if failures:
        print(f"{RED}verification FAILED{RESET}: "
              f"{', '.join(failures)}")
        return 1
    print(f"{GREEN}verification passed{RESET}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
