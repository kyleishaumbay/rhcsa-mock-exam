#!/usr/bin/env python3
"""Check a generated RHCSA mock exam (paper .docx, key .docx, grader .sh) against the
skill's rules. Usage: python3 tools/check_mock_output.py <folder> [--rhel 9|10]
Prints PASS/FAIL per rule; exit status 1 if any rule fails. Needs only python3 and bash."""
import argparse, glob, os, re, subprocess, sys, zipfile

ap = argparse.ArgumentParser()
ap.add_argument("folder")
ap.add_argument("--rhel", default="9", choices=["9", "10"])
a = ap.parse_args()
os.chdir(a.folder)

def docx_text(path):
    with zipfile.ZipFile(path) as z:
        xml = z.read("word/document.xml").decode("utf-8", "replace")
    xml = re.sub(r"</w:p>", "\n", xml)
    return re.sub(r"<[^>]+>", "", xml)

docs = sorted(glob.glob("**/*.docx", recursive=True))
keys = [d for d in docs if re.search(r"key", d, re.I)]
papers = [d for d in docs if d not in keys]
graders = sorted(glob.glob("**/*grade*.sh", recursive=True))
results = []
def rule(name, ok, detail=""):
    results.append(ok)
    print(f"{'PASS' if ok else 'FAIL'}  {name}" + (f"  ({detail})" if detail else ""))

rule("paper .docx present", bool(papers), ", ".join(papers) or "none")
rule("separate key .docx present", bool(keys), ", ".join(keys) or "none")
rule("grader .sh present", bool(graders), ", ".join(graders) or "none")
if not (papers and keys and graders):
    sys.exit(1)

paper, key, grader = docx_text(papers[0]), docx_text(keys[0]), open(graders[0]).read()
# judge only the task list: from a "Tasks" heading to "When time is up" (setup blocks may hold commands)
m = re.search(r"^\s*Tasks\s*$(.*?)(^\s*When time is up|\Z)", paper, re.M | re.S | re.I)
tasks_text = m.group(1) if m else paper

# grader structure
rc = subprocess.run(["bash", "-n", graders[0]], capture_output=True, text=True)
rule("grader passes bash -n", rc.returncode == 0, rc.stderr.strip()[:120])
rule("grader built on grader_lib v2 (need/must, --all)", "grader_lib.sh v2" in grader and "need()" in grader)
tasks = re.findall(r"^task (\d+) (\w+) (\w+) ", grader, re.M)
funcs = set(re.findall(r"^t(\d+)\(\)", grader, re.M))
n = len(tasks)
rule("18-22 tasks (full paper)", 18 <= n <= 22, f"{n} tasks")
rule("one t<n> check per task", all(t[0] in funcs for t in tasks), f"{len(funcs)} check functions")
rule("checks use need/must", len(re.findall(r"^\s+(need|must) ", grader, re.M)) >= n)
rule("stacked tasks declared with requires", bool(re.search(r"^requires \d+", grader, re.M)))
nodes = {t[2] for t in tasks}
rule("two nodes used", {"node1", "node2"} <= nodes, ", ".join(sorted(nodes)))

# syllabus coverage
cats = {t[1] for t in tasks}
want = {"TOOLS", "SH", "OPS", "STOR", "FS", "DEP", "NET", "USR", "SEC"} | ({"CON"} if a.rhel == "9" else {"SW"})
rule(f"all {len(want)} RHEL {a.rhel} objective categories present", want <= cats, "missing: " + ",".join(sorted(want - cats)) if want - cats else "")
biggest = max((sum(1 for t in tasks if t[1] == c) for c in cats), default=0)
rule("no category over a quarter of the paper", biggest <= max(1, n // 4) + 1, f"largest category has {biggest}")
low = tasks_text.lower()
must_have = {
    "node2 root password reset": r"(reset|recover|change)[^.\n]{0,40}root password|root password[^.\n]{0,40}(reset|recover|lost|unknown|forgot)|interrupt[^.\n]{0,20}boot",
    "networking (static IPv4/IPv6)": r"ipv6|gateway",
    "repository configuration": r"repositor",
    "LVM": r"logical volume|volume group",
    "swap": r"\bswap\b",
    "NFS or autofs": r"\bnfs\b|autofs",
    "SELinux": r"selinux",
    "firewall": r"firewall",
    "scheduled job (cron/at)": r"\bcron|\bat\b.*job|every (day|hour|minute)|schedul",
    "shell script": r"script",
}
if a.rhel == "9":
    must_have["rootless container with systemd"] = r"container"
else:
    must_have["flatpak"] = r"flatpak"
for label, rx in must_have.items():
    rule(f"paper covers: {label}", bool(re.search(rx, low)))
if a.rhel == "9":
    rule("no Flatpak on a RHEL 9 paper", "flatpak" not in low)
else:
    rule("no containers on a RHEL 10 paper", not re.search(r"podman|container", low))
rule("no Stratis/VDO", not re.search(r"stratis|\bvdo\b", low + key.lower()))

# honesty of the paper: no answers in it
answer_cmds = re.findall(r"\b(lvcreate|vgcreate|useradd|semanage|firewall-cmd|nmcli con|systemctl enable|crontab -e|chmod \d)", tasks_text)
rule("task list contains no solution commands", len(answer_cmds) == 0, f"{len(answer_cmds)} found: {sorted(set(answer_cmds))[:5]}")
rule("key contains solution commands", len(re.findall(r"\b(lvcreate|useradd|semanage|firewall-cmd|systemctl enable)", key)) >= 5)
rule("paper says nodes are rebooted before grading", "reboot" in paper.lower())

print(f"\n{sum(results)}/{len(results)} rules passed")
sys.exit(0 if all(results) else 1)
