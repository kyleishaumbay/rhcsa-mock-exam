# Eval suite

Run from the repo root (each case is a fresh Claude with only this plugin, in a throwaway workspace):

```
claude plugin eval ./plugins/rhcsa-mock-exam --tag light --ablation none --no-publish        # 6 quick chat cases
claude plugin eval ./plugins/rhcsa-mock-exam --case full-exam-default --ablation none \
  --allow-tools Bash Write Edit --keep-temp --no-publish                                     # one full exam (heavier)
python3 tools/check_mock_output.py <kept workspace of full-exam-default>                     # 28 deterministic rules
```

`full-exam-default` checks the default behaviour: with no topics named, the skill must produce a full
18-22 task paper across all ten RHEL 9 objective categories, a separate key, and a v2 grader that passes
`bash -n`. The eval only checks that the files exist; `tools/check_mock_output.py` checks their content.
