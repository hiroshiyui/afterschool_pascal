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

r"""Every link this tree writes down still points at something.

**A dead relative link renders exactly like a live one.** That is the whole
argument: nothing about the page says the target is gone, so the only way to
find out is to click it, and nobody clicks the links in a document they are
reading for its prose. `doc/adr/README.md` -- the index every record is found
through -- pointed at `0374-a-windows-program-runs.md` for a day, the record
having been renamed when the decision became *and Windows is deferred*, and
the sixth audit of `doc/sop.md` §7 found it by hand. A sweep then found eight
more, every one an ADR renamed after something cited it.

The class is the same one `markdown-tables` exists for and it is the reason
this is a gate rather than a proofread: **every other oracle here reads
Pascal, C or a golden**, and a link is none of those. It is also the cheapest
possible check of a property the records depend on -- ADR-0001 makes a record
immutable, so the only way a citation stays reachable is that the name it
cites does not move without every citer moving with it.

**Two claims, and the second is the one a reader actually follows.**

- A relative target exists, resolved against the linking file's own directory
  -- which is where a link copied from `README.md` into `doc/` goes wrong,
  being off by one level and still rendering.
- A `#fragment` names a heading of the document it points into, under
  GitHub's own slug rules: lowered, code spans and emphasis unwrapped,
  punctuation dropped, and **each space replaced by a hyphen without
  collapsing runs** -- so an em dash between two words leaves `--`, which is
  why eleven live anchors look broken to a slug function that collapses.

What it does not check is anything off this machine: an `http://` target is
somebody else's to keep alive and asking would put the network in the suite.

**It walks, and asks git only to subtract**, which is `format_check.py`'s
arrangement and was learned the hard way twice: `git ls-files` exits 128 in a
container whose checkout git calls dubiously owned, and a sweep that reads that
as an empty answer sweeps nothing. This one asked outright and *failed* every
container job, which is the better of the two ways to be wrong and still the
wrong one. So the files come from the tree, `doc/vendor/` and the rest are
skipped by name, and where git will speak its ignore list is subtracted.

    markdown_links.py [root]
"""

import re
import subprocess
import sys
from pathlib import Path

# A sweep that reads nothing prints a number and passes (ADR-0282). These are
# the floors, well under what the tree holds, so they fall only if the sweep
# has stopped finding documents rather than because a document was deleted.
LINK_FLOOR = 400
ANCHOR_FLOOR = 100

# `](target)`, the inline-link form, which is also `![alt](target)`: a missing
# image is a dead link too. Reference definitions are not used in this tree.
LINK = re.compile(r"\]\(\s*(<[^>]*>|[^)\s]*)\s*(?:\"[^\"]*\")?\)")

FENCE = re.compile(r"^\s*(```|~~~)")


def strip_code(text, spans=True):
    r"""The text with fenced blocks -- and by default inline code spans --
    blanked out.

    A code example may hold something shaped like a link -- a `sed`
    expression, a chunk of Markdown being quoted -- and it names no file this
    tree has to keep. Lines are kept so a report can still cite one.

    **A heading is read with `spans=False`**, because a code span in a
    heading is part of its anchor: `#### A record has no \`Drop\`` answers to
    `a-record-has-no-drop`, and blanking the span first answers to
    `a-record-has-no` and calls a live link dead. That was this check's own
    first false positive and it found a real one on the next run."""
    out, fence = [], False
    for line in text.split("\n"):
        if FENCE.match(line):
            fence = not fence
            out.append("")
            continue
        out.append("" if fence else
                   (re.sub(r"`[^`]*`", "", line) if spans else line))
    return "\n".join(out)


def slug(heading):
    """GitHub's anchor for a heading, which is not `re.sub(r'\\s+', '-')`."""
    h = heading.strip().lower()
    h = re.sub(r"`([^`]*)`", r"\1", h)
    h = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", h)
    h = re.sub(r"\*\*?|__?|~~", "", h)
    h = re.sub(r"[^\w\s-]", "", h, flags=re.UNICODE)
    return h.strip().replace(" ", "-")


def headings(text):
    """Every heading's anchor, with GitHub's `-1`, `-2` for repeats."""
    seen, out = {}, []
    for line in strip_code(text, spans=False).split("\n"):
        if re.match(r"#{1,6}\s", line):
            s = slug(line.lstrip("#").strip())
            n = seen.get(s, 0)
            seen[s] = n + 1
            out.append(s if n == 0 else f"{s}-{n}")
    return set(out)


# `doc/vendor/` is the two standards, which are not ours; `build/` is
# generated; `.claude/worktrees` is a background agent's own git worktree,
# which lives inside the checkout and would be read as a second copy of every
# document. `markdown_tables.py` skips exactly these three.
SKIP = ("build", "doc/vendor", ".claude/worktrees")


def documents(root):
    """Every Markdown file in the tree, less what git ignores where git will
    say.

    Not `git ls-files`: it exits 128 in a container whose checkout git calls
    dubiously owned, which is every containerised job here. `check-ignore`
    exits 1 when nothing matched, which is the ordinary case, and 128 in that
    same situation -- so only the first is a list to subtract, and a git that
    will not speak leaves the walk's own answer standing."""
    found = sorted(p for p in root.rglob("*.md")
                   if not str(p.relative_to(root)).startswith(SKIP))
    if not found:
        return found
    rel = [str(p.relative_to(root)) for p in found]
    ignored = subprocess.run(["git", "-C", str(root), "check-ignore", "--stdin"],
                             input="\n".join(rel), capture_output=True,
                             text=True)
    if ignored.returncode in (0, 1):
        drop = set(ignored.stdout.split())
        found = [p for p in found if str(p.relative_to(root)) not in drop]
    return found


def main():
    root = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    files = documents(root)
    anchors = {}
    for p in files:
        anchors[p.resolve()] = headings(p.read_text(encoding="utf-8",
                                                    errors="replace"))
    bad, links, frags = [], 0, 0
    for p in files:
        text = strip_code(p.read_text(encoding="utf-8", errors="replace"))
        for i, line in enumerate(text.split("\n"), 1):
            for m in LINK.finditer(line):
                target = m.group(1).strip("<>")
                if not target or target.startswith(
                        ("http://", "https://", "mailto:", "ftp://")):
                    continue
                path, _, frag = target.partition("#")
                if path:
                    links += 1
                    dest = (p.parent / path).resolve()
                    if not dest.exists():
                        bad.append(f"{p.relative_to(root)}:{i}: {path} does not "
                                   f"exist -- a renamed file, or a link copied "
                                   f"from a document one directory up")
                        continue
                else:
                    dest = p.resolve()
                if not frag:
                    continue
                frags += 1
                known = anchors.get(dest)
                if known is None:          # a link into something not Markdown
                    continue
                if frag not in known:
                    bad.append(f"{p.relative_to(root)}:{i}: "
                               f"{path or p.name}#{frag} names no heading "
                               f"there -- a heading reworded without its "
                               f"citers")
    if links < LINK_FLOOR or frags < ANCHOR_FLOOR:
        print(f"markdown-links: only {links} link(s) and {frags} anchor(s) "
              f"across {len(files)} files; the sweep is reading nothing",
              file=sys.stderr)
        return 1
    if bad:
        for b in bad:
            print(b)
        print()
        print(f"markdown-links: {len(bad)} dead link(s). A dead relative link "
              f"renders exactly like a live one, which is why this is checked "
              f"rather than read.")
        return 1
    print(f"markdown-links: {links} relative link(s) and {frags} anchor(s) "
          f"across {len(files)} files, every one resolving")
    return 0


if __name__ == "__main__":
    sys.exit(main())
