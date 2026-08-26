#!/usr/bin/env python3
"""Does each recorded mutation still fail the test that is supposed to catch it?

`doc/sop.md` §4 has required a mutation with every fix since the beginning, and
every one of them has lived in the prose of a decision record. That makes them
*claims* -- "removing this line leaves all 623 cases green over a restored
out-of-bounds write" -- which nobody can re-run and which decay silently: the
test named may be renamed, the code may move, and a later change may make the
mutation stop being caught by anything. This turns each into a file the harness
executes.

**It is not a ctest gate and must not become one.** It edits the source tree
and rebuilds, so it cannot run beside anything; ctest would run it in parallel
with 700 cases reading the same build directory. It is run deliberately, before
a release and after a change to something a mutant names.

What it does, per mutant: apply the substitution, rebuild, run the named test,
and require it to **fail**. Then restore and rebuild -- in that order and
always, including on an exception or a Ctrl-C, because a mutated tree left
behind is worse than no run at all.

Three rules it enforces, each learned the expensive way and each recorded in
`doc/sop.md` §4:

  - **The `old` text must occur exactly once.** A mutation that matched twice
    would change two things and prove neither; one that matched none would
    "pass" by mutating nothing at all, which is the shape a silent skip takes.
  - **A mutation that breaks the build proves nothing.** A compile error is
    reported as BUILD-FAILED and fails the run: the mutant has to produce a
    working compiler with the defect back in it.
  - **Restore does not preserve mtime, and rebuilds.** `cp -p` leaves the
    mutant binary in the build tree; restoring the mtime correctly and not
    rebuilding does exactly the same thing and looks less like a mistake. It
    cost a golden taken against a mutant on 2026-08-25 (ADR-0205).

And one the records could not enforce: a mutant that *loops* fills the disk
before anything notices -- 38 GB once. Every test run here is given a wall
clock and a file-size limit of its own.
"""

import argparse
import os
import resource
import signal
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MUTANTS = os.path.join(ROOT, "tests", "mutation", "mutants")
BUILD = os.path.join(ROOT, "build")

# A looping mutant wrote 38 GB before anything noticed. The build is not run
# under this -- an .ll for the compiler is tens of megabytes -- only the test.
FSIZE_LIMIT = 512 * 1024 * 1024
DEFAULT_TIMEOUT = 120


class Mutant:
    def __init__(self, path):
        self.path = path
        self.id = os.path.basename(path)[: -len(".mut")]
        self.adr = self.file = self.kills = self.why = ""
        self.timeout = DEFAULT_TIMEOUT
        self.old = self.new = ""
        self._parse()

    def _parse(self):
        head, old, new, where = [], [], [], "head"
        for line in open(self.path):
            if line.rstrip("\n") == "--- old":
                where = "old"
                continue
            if line.rstrip("\n") == "--- new":
                where = "new"
                continue
            {"head": head, "old": old, "new": new}[where].append(line)
        for line in head:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            key, _, value = line.partition(":")
            key, value = key.strip(), value.strip()
            if key == "timeout":
                self.timeout = int(value)
            elif key in ("adr", "file", "kills", "why"):
                setattr(self, key, value)
            else:
                die("%s: unknown field %r" % (self.id, key))
        for field in ("file", "kills", "why"):
            if not getattr(self, field):
                die("%s: no %s:" % (self.id, field))
        # The trailing newline of the last body line belongs to the separator,
        # not to the text, so a substitution never carries one in.
        self.old = "".join(old).rstrip("\n")
        self.new = "".join(new).rstrip("\n")
        if not self.old:
            die("%s: empty 'old'" % self.id)
        if self.old == self.new:
            die("%s: 'new' is 'old': the mutant changes nothing" % self.id)


def die(message):
    sys.stderr.write("mutation: %s\n" % message)
    sys.exit(2)


def run(cmd, timeout=None, limit_file_size=False):
    """Run a command, and on a timeout kill *everything it started*.

    The child here is ctest, which starts run_test.sh, which starts the
    compiled program -- and several mutations in this catalogue are killed
    precisely by making that program loop for ever. `subprocess.run(timeout=)`
    kills the direct child and nothing beneath it, so the looping binary was
    surviving the harness that timed it out: four of them were found spinning
    at 99.9% CPU hours after the run that made them, holding the machine at a
    load average of 5.8 and making every later measurement on it unreliable.

    So the child gets a session of its own and the whole group is killed. This
    is the third condition this harness has had to learn -- after the file-size
    limit (a looping mutant filled a disk) and the mtime-preserving restore (a
    mutant binary stayed in the build tree) -- and it has the same shape as
    both: the mutation is supposed to misbehave, so the harness has to be the
    thing that is careful.
    """
    def prepare():
        if limit_file_size:
            resource.setrlimit(resource.RLIMIT_FSIZE, (FSIZE_LIMIT, FSIZE_LIMIT))

    # start_new_session puts the child in a session and process group of its
    # own, which is what makes the group kill below safe to aim.
    p = subprocess.Popen(cmd, cwd=ROOT, preexec_fn=prepare,
                         start_new_session=True,
                         stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    try:
        out, _ = p.communicate(timeout=timeout)
        return p.returncode, out.decode("utf-8", "replace")
    except subprocess.TimeoutExpired:
        # Kill the group, but *only* once it is established that the group is
        # the child's own and not this process's. Getting that wrong kills the
        # harness mid-run and leaves a mutation applied to the tree, which is
        # this harness's worst failure and the one its restore step exists to
        # prevent -- so the check is not defensive padding, it is the whole
        # reason a group kill is safe to attempt at all.
        try:
            pgid = os.getpgid(p.pid)
            if pgid != os.getpgrp():
                os.killpg(pgid, signal.SIGKILL)
            else:
                p.kill()
        except (ProcessLookupError, PermissionError, OSError):
            p.kill()
        p.communicate()
        return None, ""


def build():
    code, out = run(["cmake", "--build", BUILD, "-j"], timeout=1800)
    return code == 0, out


def restore(mutant):
    """Put the file back and rebuild. Never `cp -p`, never without the build."""
    subprocess.run(["git", "checkout", "--", mutant.file], cwd=ROOT, check=False)
    os.utime(os.path.join(ROOT, mutant.file), None)
    build()


def apply_to(mutant):
    path = os.path.join(ROOT, mutant.file)
    text = open(path).read()
    hits = text.count(mutant.old)
    if hits != 1:
        return "the 'old' text occurs %d times in %s, not once" % (hits, mutant.file)
    open(path, "w").write(text.replace(mutant.old, mutant.new, 1))
    return None


def check(mutant, verbose):
    problem = apply_to(mutant)
    if problem:
        return "NOT-APPLIED", problem
    try:
        ok, out = build()
        if not ok:
            return "BUILD-FAILED", "a mutant must produce a working compiler"
        # `--timeout` is a *default* and a case's own TIMEOUT property beats
        # it, so the clock that always applies is this one. Every dialect case
        # has such a property (ADR-0205), which is exactly where a blocking
        # mutant lives -- so relying on ctest's would have meant waiting 300
        # seconds for a mutant asking for 30.
        code, out = run(["ctest", "--test-dir", BUILD, "-R", "^%s$" % mutant.kills,
                         "--timeout", str(mutant.timeout), "--output-on-failure"],
                        timeout=mutant.timeout + 30, limit_file_size=True)
        if verbose:
            sys.stdout.write(out)
        if code is None:
            return "KILLED", "timed out: the defect blocks rather than prints"
        if code == 0:
            return "SURVIVED", "%s passed with the defect in it" % mutant.kills
        if "Unable to find executable" in out or "No tests were found" in out:
            return "NO-SUCH-TEST", "no test named %s" % mutant.kills
        return "KILLED", ""
    finally:
        restore(mutant)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", help="run one mutant by id")
    ap.add_argument("--list", action="store_true")
    ap.add_argument("--verbose", action="store_true")
    ap.add_argument("--allow-dirty", action="store_true",
                    help="run with uncommitted changes; restore then loses them")
    args = ap.parse_args()

    names = sorted(n for n in os.listdir(MUTANTS) if n.endswith(".mut"))
    mutants = [Mutant(os.path.join(MUTANTS, n)) for n in names]
    if args.only:
        mutants = [m for m in mutants if m.id == args.only]
        if not mutants:
            die("no mutant named %r" % args.only)

    if args.list:
        for m in mutants:
            print("%-34s %-22s kills %s" % (m.id, m.file, m.kills))
        print("mutation: %d mutants" % len(mutants))
        return 0

    # Restore is `git checkout --`, so an uncommitted change to a file a mutant
    # names would be thrown away by a successful run. Refusing is the whole
    # safety story and is why this is not a ctest case.
    dirty = subprocess.run(["git", "status", "--porcelain"], cwd=ROOT,
                           stdout=subprocess.PIPE).stdout.decode()
    touched = set(m.file for m in mutants)
    at_risk = [l[3:] for l in dirty.splitlines() if l[3:].strip() in touched]
    if at_risk and not args.allow_dirty:
        die("uncommitted changes to %s, which restore would discard; commit "
            "first or pass --allow-dirty" % ", ".join(sorted(at_risk)))

    for sig in (signal.SIGINT, signal.SIGTERM):
        signal.signal(sig, lambda *_: die("interrupted; the tree is restored"))

    bad = 0
    for m in mutants:
        verdict, note = check(m, args.verbose)
        line = "%-34s %-13s %s" % (m.id, verdict, note or m.why)
        print("mutation: " + line.rstrip())
        sys.stdout.flush()
        if verdict != "KILLED":
            bad += 1
    print("mutation: %d mutants, %d not killed" % (len(mutants), bad))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
