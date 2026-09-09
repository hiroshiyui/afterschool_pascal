# ADR-0377: A link is followed by nobody

## Status

Accepted. Adds `markdown-links` beside `markdown-tables`, and repairs nine
dead links found by writing it.

## Context

The sixth audit of `doc/sop.md` §7 (2026-09-09) found the register itself
clean and four defects in the documents around it. One was `doc/adr/README.md`
— the index every decision record is reached through — with its row for
ADR-0374 pointing at `0374-a-windows-program-runs.md`. The record is
`0374-windows-runs-and-is-deferred.md`; it was renamed the day before, when
the decision became *Windows runs, **and Windows is deferred***, and the index
row kept the old name.

**Markdown renders a dead relative link exactly like a live one.** There is no
warning, no colour, no difference in the page: the only way to discover it is
to follow the link, and nobody follows the links in a document they are
reading for its prose. That is why it survived a full documentation sync on
the day the rename happened and was found by a person a day later.

A sweep of the tree then found **eight more**, every one an ADR renamed after
something had already cited it:

| Citing record | Named | Is now |
| --- | --- | --- |
| 0239 | `0085-retire-stage-0.md` | `0085-stage-0-is-retired.md` |
| 0252 | `0201-a-borrow-cannot-outlive-a-call.md` | `0201-aliasing-was-answered-too-…md` |
| 0252, 0257 | two spellings of ADR-0205 | `0205-a-server-serves-many-clients-…md` |
| 0254 | `0211-a-routine-may-be-generic-over-a-type.md` | `0211-a-routine-may-be-parameterised-by-a-type.md` |
| 0293 | `0017-name-equivalence-and-checked-subscripts.md` | `0017-structured-types-use-name-equivalence.md` |
| 0300 | `0283-a-var-parameter-nothing-writes-through.md` | `0283-a-parameter-that-could-say-it-is-read-only.md` |
| 0308 | `0244-an-import-is-found-where-the-program-is.md` | `0244-an-import-that-names-no-file.md` |
| 0311 | `0242-a-document-is-not-a-file-the-compiler-can-open.md` | `0242-a-name-no-other-live-process-will-choose.md` |

Every one is the same mechanism: a record's *title* was still being settled
while it was being written, the file was renamed to match, and the citations
already made were not moved with it. **ADR-0001 makes a record immutable once
Accepted**, so a citation is permanent — which means the only thing keeping it
reachable is that nothing renames its target silently.

This is the class `markdown-tables` exists for, met a second time: **every
other oracle in this repository reads Pascal, C or a golden**, and a link is
none of those.

## Decision

**Every relative link in a tracked Markdown file must resolve**, and
`tests/checks/markdown_links.py` is the gate. Two claims:

1. **The target exists**, resolved against the linking file's own directory —
   which is where a link copied from `README.md` into `doc/` goes wrong, being
   off by one level and still rendering. 698 today.
2. **A `#fragment` names a heading of the document it points into**, under
   GitHub's slug rules. 185 today, and this half catches the other way a link
   dies: the file stays and the heading is reworded.

**What git tracks is what it sweeps** — `variant-check`'s rule (ADR-0223): a
scratch document in the working tree states nothing this repository has to
keep, and `doc/vendor/` is the two standards, gitignored and not ours to fix.

**An `http://` target is not checked.** Somebody else keeps it alive, and
asking would put the network in the suite — a gate that fails when a server is
down is a gate people learn to ignore.

**It has floors** (ADR-0282): 400 links and 100 anchors, well under what the
tree holds, so a sweep that has stopped finding documents fails rather than
printing a number and passing.

## Consequences

Nine dead links are repaired in the same commit — the eight above and the
index row the audit found. A link repair is not an edit to an accepted
record's reasoning: the prose is untouched, every link's text is `ADR-00NN`,
and what changes is only the name of the file that text has always meant.

**The anchor half found a tenth on its first run**, which is the half that
would otherwise have been argued as not worth writing:
`doc/history.md` cited `roadmap.md#a-record-has-no-drop`, and its own first
version of `slug()` — collapsing runs of whitespace — called eleven *live*
anchors dead. GitHub replaces each space with a hyphen and does not collapse,
so an em dash between two words leaves `--` in the anchor. A slug function
that is wrong in that direction is worse than no gate, because what it reports
is a document that is right.

**And the gate's own first false positive is recorded in its source**: it read
headings through the same code-span stripper it uses on body text, so
`#### A record has no \`Drop\`` answered to `a-record-has-no` and the live link
above was reported dead. A heading's code span is part of its anchor. The
lesson is `foreign-width`'s (ADR-0376) in a cheaper place — the first version
of a catalogue gate reports a difference that is not one, and the false
positive looks exactly like the finding.

Cost: one Python file, no dependency, and it runs in 0.3 s.

**Its first CI run failed in all four container jobs, and the hazard was
already written down here.** It asked `git ls-files` for the documents to
sweep; git exits 128 in a container whose checkout it calls dubiously owned,
which is every containerised job in this workflow, and the check turned that
into *this is not a git checkout*. `tests/checks/format_check.py` carries a
comment about exactly this, put there when the same call made *that* sweep
read an empty list and pass — the better-known half of the failure, and the
reason its floor exists. So the arrangement is now that file's: **walk the
tree, skip `build/`, `doc/vendor/` and `.claude/worktrees` by name, and ask
git only to subtract its ignore list**, tolerating a git that will not answer.
The cost is that an untracked scratch document in the checkout is swept, which
is what `markdown-tables` has always done.

The lesson is not *use the other call*. It is that **a helper reading a
repository has two answers to distinguish and usually distinguishes one**: git
saying *nothing matched* and git refusing to speak. Both of this tree's
instances came of collapsing them, in opposite directions.

## Alternatives rejected

**Check `http://` targets too.** It would have found the one thing this cannot
— a page that has moved — at the price of a suite that fails when a host is
down, and of putting the network into `ctest`. The trade is the same one
`fpc-differential` and `tls` make in the other direction: an external oracle is
worth having when it is *deterministic*, and reachability is not.

**A Markdown linter.** There is none here and adding one would be a change to
405 files rather than a check. `markdown-tables` made this argument first and
it has not weakened: what is checked is the two structural properties that
have actually failed, and nothing about style.

**Nothing, on the grounds that a renamed ADR is rare.** It has happened nine
times, all of them invisible, and the index — the one document whose whole job
is to be a set of links — was among them.
