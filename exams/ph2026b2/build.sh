#!/bin/bash
# Build each mock's grader: grader_lib.sh + helpers.sh + that mock's checks.sh -> one file.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
lib=$here/../../plugins/rhcsa-mock-exam/skills/rhcsa-mock-exam/scripts/build_grader.sh
for n in 1 2; do
  [[ -f $here/mock-$n/checks.sh ]] || continue
  tmp=$(mktemp); cat "$here/helpers.sh" "$here/mock-$n/checks.sh" > "$tmp"
  bash "$lib" "$tmp" "$here/mock-$n/rhcsa9-mock-$n-grade.sh"
  sed -i "1r $here/usage-$n.txt" "$here/mock-$n/rhcsa9-mock-$n-grade.sh"; rm -f "$tmp"
done
