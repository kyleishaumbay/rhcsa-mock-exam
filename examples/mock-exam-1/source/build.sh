#!/bin/bash
# Rebuild the example's grader and documents.  Needs: python3 with python-docx (pip install python-docx)
set -euo pipefail
cd "$(dirname "$0")"
LIB=../../../plugins/rhcsa-mock-exam/skills/rhcsa-mock-exam/scripts
bash "$LIB/build_grader.sh" grader_tasks.sh ../rhcsa9-mock-1-grade.sh
"${PYTHON:-python3}" build_docs.py ..
echo "Built rhcsa9-mock-1-grade.sh, RHCSA9_Mock_Exam_1.docx, RHCSA9_Mock_Exam_1_Key.docx"
