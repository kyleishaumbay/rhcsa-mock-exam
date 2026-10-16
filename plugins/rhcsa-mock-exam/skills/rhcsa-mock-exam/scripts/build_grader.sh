#!/bin/bash
# build_grader.sh <checks.sh> [out.sh]
# Prepend grader_lib.sh to a paper's checks so the grader ships as one file,
# then make it executable and syntax-check it. Write only the checks; never retype the library.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
in=${1:?usage: build_grader.sh <checks.sh> [out.sh]}
out=${2:-${in%.sh}-grade.sh}
{ cat "$here/grader_lib.sh"; printf '\n# ==== paper checks (%s) ====\n' "$(basename "$in")"; cat "$in"; } > "$out"
chmod +x "$out"
bash -n "$out"
echo "built $out ($(grep -c '^task ' "$out") tasks)"
