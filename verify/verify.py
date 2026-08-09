#!/usr/bin/env python3
"""Formal verification of Afterschool Pascal's lowering rules.

Two halves, and neither is sufficient alone:

  --prove       Ask Z3 whether any input makes a lowering disagree with the ISO
                specification. `unsat` on the negated claim means the rule holds
                for all 2^64 inputs — the thing testing cannot establish.

  --crosscheck  Compile and run a real Pascal program with the real compiler at
                the adversarial points, and compare against the specification
                computed independently in Python.

The proof half reasons about `lowering.py`, which is a hand-written model of
`codegen.cpp`. That model can drift from the compiler, and a proof about a stale
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
    print(f"\n  {proved} rules claimed correct "
          f"({proved - bounded} at the full 32-bit width, {bounded} bounded), "
          f"{gaps} known gaps documented")
    if bounded:
        print(f"  {DIM}* bounded: the claim involves a symbolic division or "
              f"multiplication, which\n"
              f"    bit-blasts into a circuit too large to solve at 32 bits. "
              f"It is established\n"
              f"    exhaustively at small widths instead. The lowering is the "
              f"same instruction\n"
              f"    sequence at every width, which is the argument for "
              f"generalising — but it is\n"
              f"    an argument, not a proof.{RESET}")
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


def iso_div(i, j):
    """Truncating division, stated independently of the compiler."""
    q = abs(i) // abs(j)
    return q if (i >= 0) == (j >= 0) else -q


def iso_mod(i, j):
    """The unique r with 0 <= r < j and j | (i - r); j > 0 only."""
    assert j > 0
    return i - j * (i // j)


def build_crosscheck_program():
    lines = ["program Crosscheck(output);", "var i, j: integer;", "begin"]
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
    parser.add_argument("--pascalc", default="build/bin/pascalc",
                        help="path to the compiler under test")
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
