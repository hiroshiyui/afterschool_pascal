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

"""Regenerate the clause inventories from the standards, when they are present.

  tests/spec/clauses/extract_pdfs.py

What it writes is *clause numbers and their short headings* -- the structure
of the documents, which is what a citation names -- and no other text. The
online copies in doc/vendor/ carry the notice "Do not modify this document.
Do not include this document in another software product", and doc/vendor is
not in this repository for that reason. The inventories are, because a clause
number is a citation and a suite that could not cite one would have nothing
to be traceable to.

The .tsv files are committed, so this only has to run when the inventory is
in doubt. It needs `pdftotext` (poppler-utils) and the PDFs; without either
it says so and changes nothing.

Converted from tests/spec/clauses/extract_pdfs.py under ADR-0366.
"""

import os
import shutil
import subprocess
import sys
import tempfile

# The parser this hands each extracted text file to. It is a separate program
# with its own usage and its own exit status, and is invoked as one -- through
# this interpreter rather than through a `python3` found on PATH.
PARSER = "extract.py"

PAIRS = [("iso7185", "ISO 7185:1990"), ("iso10206", "ISO/IEC 10206:1991")]


def main():
    sys.stdout.reconfigure(line_buffering=True)
    here = os.path.realpath(os.path.dirname(os.path.abspath(__file__)))
    vendor = os.path.realpath(os.path.join(here, "..", "..", "..", "doc", "vendor"))
    if not os.path.isdir(vendor):
        print("extract: doc/vendor is not present -- leaving the inventories alone",
              file=sys.stderr)
        return 0
    if shutil.which("pdftotext") is None:
        print("extract: pdftotext is not installed (apt install poppler-utils)",
              file=sys.stderr)
        return 0

    # The status of the loop is the status of the last command it ran, which is
    # what the shell reported and what a caller of this reads.
    status = 0
    work = tempfile.mkdtemp()
    try:
        for name, standard in PAIRS:
            pdf = os.path.join(vendor, name + ".pdf")
            if not os.path.isfile(pdf):
                print(f"extract: no {name}.pdf", file=sys.stderr)
                status = 0
                continue
            text = os.path.join(work, name + ".txt")
            status = subprocess.run(["pdftotext", "-layout", pdf, text]).returncode
            status = subprocess.run(
                [sys.executable, os.path.join(here, PARSER),
                 text, os.path.join(here, name + ".tsv"), standard]).returncode
    finally:
        shutil.rmtree(work, ignore_errors=True)
    return status


if __name__ == "__main__":
    sys.exit(main())
