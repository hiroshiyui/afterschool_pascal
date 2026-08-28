#!/bin/bash
# Build an audit sandbox: a directory holding everything an independent reader
# needs and nothing that would tell it what this project decided.
#
# ADR-0107 recorded that isolation failed on all seven readers of the first
# real run, identically, and named the cause: "This is a property of running
# the skill in-process, not of its instructions."  The instructions already
# asked readers not to read CLAUDE.md; the harness injected it anyway, before
# a reader's first turn, and none could decline.
#
# So isolation stops being asked for and starts being built.  A reader is
# launched against THIS directory, outside the repository, so that
#
#   - there is no CLAUDE.md above it to discover;
#   - the project-scoped auto-memory is keyed on the repository's path and
#     does not match this one;
#   - doc/adr/, doc/design-digest.md, doc/roadmap.md, doc/sop.md, README.md,
#     the commit history and tests/spec/features/ are simply absent.
#
# and the compiler's source arrives with its comments removed, which is the
# part that is easy to miss: selfhost/compiler.pas carries 791 ADR citations
# and 1755 clause citations -- 41% of what all of doc/adr/ holds -- and its
# comments argue the readings rather than merely citing them.  It is the
# densest anchoring text in the tree and step 2 of the skill has always
# allowed a reader to open it.
#
# usage: sandbox.sh [target-dir]        prints the path it built

set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
dest=${1:-$(mktemp -d "${TMPDIR:-/tmp}/langspec-audit.XXXXXX")}
mkdir -p "$dest"/{standards,bin,source,probes}

missing=()

# --- the standards themselves ------------------------------------------------
# doc/vendor/ is gitignored and BSI's and ISO's terms forbid redistribution.
# Copying into a scratch directory is use, not redistribution; the sandbox must
# never be committed or published, which MANIFEST.txt repeats.
for pdf in iso7185 iso10206; do
  if [ -f "$repo/doc/vendor/$pdf.pdf" ]; then
    cp "$repo/doc/vendor/$pdf.pdf" "$dest/standards/"
  else
    missing+=("doc/vendor/$pdf.pdf")
  fi
done

# --- no third-party corpus ---------------------------------------------------
# The BSI Pascal Validation Suite was copied in here until ADR-0232. Its
# programs are conforming ISO 7185 and 25 of them use a word-symbol
# ISO/IEC 10206:1991 6.1.2 reserves, so this compiler cannot compile the corpus
# at all -- handing it to a reader would be handing over 812 programs that fail
# for one reason having nothing to do with the clause under audit. The
# standards text is now the whole of the external evidence, which SKILL.md
# step 4 says out loud, because it changes what a verdict can rest on.

# --- a toolchain, so a verdict rests on a compiled probe ---------------------
for f in "$repo/build/bin/pascalc" "$repo/build/lib/libpasrt.a"; do
  [ -f "$f" ] || { echo "sandbox: $f is missing; build first" >&2; exit 1; }
done
cp "$repo/build/bin/pascalc" "$dest/bin/pascalc"
cp "$repo/build/lib/libpasrt.a" "$dest/bin/libpasrt.a"
cp "$repo/tools/pascalcc" "$dest/bin/pascalcc.real"
cat > "$dest/bin/pascalcc" <<'WRAP'
#!/bin/sh
here=$(cd "$(dirname "$0")" && pwd)
PASCALC="$here/pascalc" AFTERSCHOOL_PASCAL_RUNTIME="$here" \
  exec "$here/pascalcc.real" "$@"
WRAP
chmod +x "$dest/bin/pascalcc"

# --- the compiler's source, with the reasoning removed -----------------------
python3 "$repo/.claude/skills/langspec-audit/strip_comments.py" \
        "$repo/selfhost/compiler.pas" "$dest/source/compiler.pas"

cat > "$dest/MANIFEST.txt" <<MAN
This directory is an audit sandbox.  It is scratch: never commit it, never
publish it, and delete it when the audit is over.  standards/ and bsi/ hold
documents whose licences permit use and not redistribution.

WHAT IS HERE
  standards/       ISO 7185 and ISO/IEC 10206:1991, as PDFs.  pdftotext -layout
                   works.  The extraction drops fi/fl ligatures -- "fixed" comes
                   out "xed", "file" comes out "le" -- and renders ^ as ".
  bin/pascalcc     compiles and links a Pascal program.  bin/pascalc writes IR
                   and stops.  Flags: -o, -S.  There is no flag that selects a
                   language: this processor implements one, and a source is
                   simply written in it.
  source/          the compiler's source with every comment removed.  Line
                   numbers match the real file, so a finding can cite one.
  probes/          write your probe programs here.

WHAT IS DELIBERATELY ABSENT, AND WHY
  CLAUDE.md, doc/adr/, doc/design-digest.md, doc/roadmap.md, doc/sop.md,
  doc/implementation-defined.md, README.md, tests/spec/features/, the git
  history, and every comment in the compiler's source.

  Each states what this project decided and why.  An audit is worth something
  only if the reader reaches its own verdict from the standards text, so the
  reasoning is withheld -- not as a courtesy, but because a reader who has seen
  it will find the implementer's sentence in the clause whether or not it is
  there.

  This is not a test of your discipline.  If you find any of it anyway, say so
  in your report: an audit's independence is a property of the harness, and a
  leak is a fact about the harness worth knowing.

MISSING FROM THIS SANDBOX
$( if [ ${#missing[@]} -eq 0 ]; then echo "  nothing"; else printf '  %s\n' "${missing[@]}"; fi )
MAN

cat > "$dest/README-reader.md" <<'RDR'
# How to compile a probe

```sh
cd probes
cat > p.pas <<'EOF'
program p(output);
begin
  writeln('hi')
end.
EOF
../bin/pascalcc p.pas -o p && ./p
```

`../bin/pascalcc` prints `file:line:col: error: message` and exits non-zero when
it refuses a program. Record what it accepts and what it refuses; that is the
behaviour under audit.

Read `MANIFEST.txt` first — it says what is here and what is not.
RDR

echo "$dest"
