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

# Regenerate the clause inventories from the standards, when they are present.
#
#   tests/spec/clauses/extract.sh
#
# What it writes is *clause numbers and their short headings* -- the structure
# of the documents, which is what a citation names -- and no other text. The
# online copies in doc/vendor/ carry the notice "Do not modify this document.
# Do not include this document in another software product", and doc/vendor is
# not in this repository for that reason. The inventories are, because a clause
# number is a citation and a suite that could not cite one would have nothing
# to be traceable to.
#
# The .tsv files are committed, so this only has to run when the inventory is
# in doubt. It needs `pdftotext` (poppler-utils) and the PDFs; without either
# it says so and changes nothing.
set -u

here=$(cd "$(dirname "$0")" && pwd)
vendor=$(cd "$here/../../../doc/vendor" 2>/dev/null && pwd) || {
  echo "extract: doc/vendor is not present -- leaving the inventories alone" >&2
  exit 0
}
command -v pdftotext >/dev/null || {
  echo "extract: pdftotext is not installed (apt install poppler-utils)" >&2
  exit 0
}

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

for pair in "iso7185:ISO 7185:1990" "iso10206:ISO/IEC 10206:1991"; do
  name=${pair%%:*}
  [[ -f "$vendor/$name.pdf" ]] || { echo "extract: no $name.pdf" >&2; continue; }
  pdftotext -layout "$vendor/$name.pdf" "$work/$name.txt"
  python3 "$here/extract.py" "$work/$name.txt" "$here/$name.tsv" "${pair#*:}"
done
