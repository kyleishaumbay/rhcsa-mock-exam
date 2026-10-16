#!/bin/bash
# Build dist/rhcsa-mock-exam.zip for uploading the skill to claude.ai
# (Settings > Capabilities > Skills > Upload skill). Needs only python3.
set -euo pipefail
cd "$(dirname "$0")/.."
bash -n plugins/rhcsa-mock-exam/skills/rhcsa-mock-exam/scripts/grader_lib.sh
mkdir -p dist
rm -f dist/rhcsa-mock-exam.zip
( cd plugins/rhcsa-mock-exam/skills && python3 -m zipfile -c ../../../dist/rhcsa-mock-exam.zip rhcsa-mock-exam )
echo "Built dist/rhcsa-mock-exam.zip"
python3 -m zipfile -l dist/rhcsa-mock-exam.zip
