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

"""Does a record declared here have the layout the C struct it claims to be has?

AP 6.7.7.6.2 lets a record cross to a foreign routine as a `var` parameter, and
what makes that sound is that RecordLayout *is* C's struct rule -- so the two
compilers agree about offsets for whatever fields are declared (ADR-0184).

What that leaves unchecked, and could not check from one side, is whether the
fields declared **are** the members the real struct has, in that order and with
that padding. `struct stat` is 144 bytes on glibc/x86-64 with two holes; write
one of them in the wrong place and every field after it is silently wrong.
ADR-0184 registered this in doc/sop.md 7 as the same claim as an `external`
signature. This is the half of it that can be closed (ADR-0185).

A source states its claim in a **comment**, which costs the language nothing --
the same route ADR-0166 took for `{ @std:iso7185 }`:

    { @cstruct: TimeSpec = struct timespec, <time.h> }
    type TimeSpec = record
      sec: int64;      { @cfield: tv_sec }
      nsec: int64      { @cfield: tv_nsec }
    end;

The gate asks the compiler what offsets it computed (`--dump-layout`), zips
them against the `@cfield:` annotations in source order, and generates a C file
of `_Static_assert`s for a C compiler holding the real headers to judge. A `-`
annotation is padding with no C member: its offset is not asserted, but it
still occupies its place, so the members after it are.

**Zipped in order rather than matched by name**, deliberately: a field whose
annotation is missing then shifts every one after it and the count check fires,
where name-matching would silently check a subset. A count mismatch is an
error and says which record.

`@cplatform:` marks a declaration that is one platform's -- `struct stat` is
not the same struct on macOS -- and the subject is skipped elsewhere rather
than failed. That is not a weakening: a declaration nobody can check on this
machine is exactly the thing this gate exists to stop being silent about, and
skipping it *here* is reported.

Skips with 77 when no C compiler is available, as target-sizes does.
"""

import os
import pathlib
import re
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent.parent

CSTRUCT = re.compile(
    r"@cstruct:\s*(\w+)\s*=\s*((?:struct\s+)?\w+)\s*,\s*<([^>]+)>")
CFIELD = re.compile(r"@cfield:\s*(\S+)")
CPLATFORM = re.compile(r"@cplatform:\s*(\S+)")

RECORD = re.compile(r"^record (\S+) size=(\d+) align=(\d+)$")
FIELD = re.compile(r"^  field (\S+) offset=(\d+) size=(\d+) align=(\d+)$")


def platform_tags():
    """What this machine answers to. Deliberately coarse."""
    tags = {sys.platform}
    if sys.platform.startswith("linux"):
        tags.add("linux")
        if (pathlib.Path("/usr/include/gnu/stubs.h").exists()
                or pathlib.Path("/usr/include/x86_64-linux-gnu/gnu/stubs.h")
                .exists()):
            tags.add("linux-glibc")
    if sys.platform == "darwin":
        tags.add("macos")
    return tags


def subjects(path):
    """The @cstruct claims in one source, each with its fields in order."""
    out, cur = [], None
    for line in path.read_text(encoding="utf-8").splitlines():
        m = CSTRUCT.search(line)
        if m:
            cur = {"pascal": m.group(1).lower(), "ctype": m.group(2),
                   "header": m.group(3), "fields": [], "platform": None,
                   "source": path}
            p = CPLATFORM.search(line)
            if p:
                cur["platform"] = p.group(1)
            out.append(cur)
            continue
        if cur is None:
            continue
        p = CPLATFORM.search(line)
        if p and not cur["fields"]:
            cur["platform"] = p.group(1)
        f = CFIELD.search(line)
        if f:
            cur["fields"].append(f.group(1))
    return out


def dumped(pascalc, source):
    """What the compiler says every record in this source looks like."""
    cmd = [pascalc, "--dump-layout", str(source),
           "-o", os.devnull]
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        print(f"foreign-layout: {source} did not compile:\n{r.stdout}"
              f"{r.stderr}", file=sys.stderr)
        return None
    records, name = {}, None
    for line in r.stdout.splitlines():
        m = RECORD.match(line)
        if m:
            name = m.group(1)
            records[name] = {"size": int(m.group(2)),
                             "align": int(m.group(3)), "fields": []}
            continue
        m = FIELD.match(line)
        if m and name:
            records[name]["fields"].append((m.group(1), int(m.group(2)),
                                            int(m.group(3))))
    return records


def probe_for(subject, record):
    """The C a compiler holding the real header can judge."""
    lines = [f"#include <{subject['header']}>", "#include <stddef.h>", ""]
    tag = subject["ctype"]
    lines.append(f'_Static_assert(sizeof({tag}) == {record["size"]},'
                 f' "sizeof({tag}) is not {record["size"]}");')
    for (pname, off, _size), cname in zip(record["fields"],
                                          subject["fields"]):
        if cname == "-":
            continue
        lines.append(
            f'_Static_assert(offsetof({tag}, {cname}) == {off},'
            f' "{tag}.{cname} is not at {off} -- the Pascal field is'
            f' {pname}");')
    lines.append("int main(void) { return 0; }")
    return "\n".join(lines) + "\n"


def main():
    pascalc = os.environ.get("PASCALC", str(ROOT / "build" / "bin" / "pascalc"))
    cc = os.environ.get("CC", "clang")
    if subprocess.run([cc, "--version"], capture_output=True).returncode != 0:
        print(f"foreign-layout: no C compiler ({cc}); skipping")
        return 77
    if not pathlib.Path(pascalc).exists():
        print(f"foreign-layout: no compiler at {pascalc}", file=sys.stderr)
        return 1

    here = platform_tags()
    found = failures = checked = skipped = 0

    for source in sorted(ROOT.rglob("*.pas")):
        # `.claude/worktrees` is a background agent's own git worktree, which
        # this harness puts inside the checkout: walking it would compile a
        # second copy of every annotated record and report each finding twice.
        # ...and the test is on the path *below* ROOT, because ROOT itself
        # may be such a worktree, and a filter over the absolute path then
        # skipped every source and reported "no claim anywhere".
        if "build" in source.relative_to(ROOT).parts \
                or ".claude" in source.relative_to(ROOT).parts:
            continue
        text = source.read_text(encoding="utf-8", errors="replace")
        if "@cstruct:" not in text:
            continue
        records = dumped(pascalc, source)
        if records is None:
            failures += 1
            continue
        for subject in subjects(source):
            found += 1
            rel = subject["source"].relative_to(ROOT)
            if subject["platform"] and subject["platform"] not in here:
                print(f"foreign-layout: {rel}: {subject['ctype']} is "
                      f"{subject['platform']}-only; not checked here")
                skipped += 1
                continue
            record = records.get(subject["pascal"])
            if record is None:
                print(f"foreign-layout: {rel}: no record named "
                      f"'{subject['pascal']}' in what the compiler dumped",
                      file=sys.stderr)
                failures += 1
                continue
            if len(record["fields"]) != len(subject["fields"]):
                print(f"foreign-layout: {rel}: {subject['ctype']} has "
                      f"{len(record['fields'])} fields and "
                      f"{len(subject['fields'])} @cfield annotations -- they "
                      f"are zipped in order, so every one needs a line "
                      f"(write '-' for padding)", file=sys.stderr)
                failures += 1
                continue
            with tempfile.TemporaryDirectory() as tmp:
                probe = pathlib.Path(tmp) / "probe.c"
                probe.write_text(probe_for(subject, record))
                r = subprocess.run([cc, "-fsyntax-only", str(probe)],
                                   capture_output=True, text=True)
                if r.returncode != 0:
                    print(f"foreign-layout: {rel}: {subject['ctype']} is not "
                          f"what this declaration says it is:\n{r.stderr}",
                          file=sys.stderr)
                    failures += 1
                    continue
            checked += 1

    if found == 0:
        print("foreign-layout: no @cstruct claim anywhere -- either the "
              "convention went away or nothing uses it, and a run that "
              "reaches nothing looks exactly like a clean one",
              file=sys.stderr)
        return 1
    if failures:
        print(f"foreign-layout: {failures} of {found} claims are wrong")
        return 1
    print(f"foreign-layout: {checked} of {found} struct claims agree with the "
          f"real headers"
          + (f" ({skipped} for another platform)" if skipped else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main())
