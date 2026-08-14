#!/usr/bin/env bash
# Fetch the BSI Pascal Validation Suite into tests/bsi/suite (gitignored).
#
# The suite is not committed here. Copyright belongs to the British Standards
# Institution, who make it available "as is" on three conditions -- that the
# copyright is acknowledged, that no representation suggests a third-party
# validation was carried out, and that any representation of results describes
# performance on the whole suite rather than selected tests -- without granting
# redistribution. doc/vendor/ holds the standards themselves on the same terms
# and is likewise ignored by git.
#
# The commit is pinned. An oracle that silently changes under you is not one,
# and "whatever is on the upstream default branch today" would make a red bar
# ambiguous between a compiler regression and a corpus edit.
set -eu

here=$(cd "$(dirname "$0")" && pwd)
url=https://github.com/pascal-validation/validation-suite.git
commit=fe0793ebfcf959a66e3bb923e8c710611de7b13e

dest=$here/suite
if [[ -d $dest ]]; then
  echo "bsi: $dest already exists; remove it to refetch" >&2
  exit 0
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

git clone -q "$url" "$tmp/suite"
git -C "$tmp/suite" checkout -q "$commit"
rm -rf "$tmp/suite/.git"
mv "$tmp/suite" "$dest"

echo "bsi: fetched validation suite 5.7 at ${commit:0:12} into $dest"
echo "bsi: (C) Copyright 1982, British Standards Institution"
