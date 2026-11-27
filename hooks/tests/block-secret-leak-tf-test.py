"""Controlled test of the Terraform file guard in block-secret-leak.py:
reads of state, plan and tfvars files are denied; commands that only name
them, or write text that mentions them, pass."""
import importlib.util
import json
import pathlib
import subprocess
import sys

HOOK = pathlib.Path(__file__).resolve().parent.parent / "block-secret-leak.py"
spec = importlib.util.spec_from_file_location("hook", HOOK)
hook = importlib.util.module_from_spec(spec)
spec.loader.exec_module(hook)

ALLOW = [
    "git check-ignore -v terraform/azure/x/terraform.tfstate",
    "git status --short",
    "git ls-files '*.tfstate'",
    "ls terraform/azure/nh-production/workloads/vm",
    "rm -f probe/probe.tfstate",
    "grep -n 'tfstate' .gitignore",
    "grep -nE '\\.tfstate|\\.tfplan' .gitignore",
    "grep -rniE 'tfstate|tfplan' CLAUDE.md rules",
    "terraform fmt -recursive",
    "terraform validate",
    "terraform plan -out=import.tfplan",
    "terraform apply import.tfplan",
    "echo '*.tfstate is gitignored'",
    "cat >> ledger.md <<'EOF'\n| row | `*.tfstate`, `*.tfplan` gitignored |\nEOF",
    "cd /c/repo && cat >> .ai-work/tasks.md <<'EOF'\n| x | terraform.tfstate |\nEOF\ngit status --short",
    "python -I - <<'EOF'\nprint('no terraform files here')\nEOF",
    "cd /c/repo && cat >> tasks.md <<'EOF'\n| x | denies `terraform show`, `state pull` |\nEOF",
]

DENY = [
    "cat terraform.tfstate",
    "cat \"$TEMP/claude/x/probe.tfplan\"",
    "head -c 100 a/b/terraform.tfstate.backup",
    "jq . plan.tfplan.json",
    "less prod.tfvars",
    "cat ./tfplan",
    "cat x.tf\"state\"",
    "grep -r password . --include=*.tfstate",
    "python -I -c \"print(open('x.tfstate').read())\"",
    "python -I - <<'EOF'\nprint(open('import.tfplan').read())\nEOF",
    "git status && cat x.tfvars",
    "git status\ncat x.tfstate",
    "echo $(cat x.tfstate)",
    "echo `cat x.tfstate`",
    "terraform show -json import.tfplan",
    "terraform show",
    "terraform -chdir=x state pull",
    "terraform state show module.vm",
    "terraform output",
    "echo 'module.vm' | terraform console",
    "bash <<'EOF'\nterraform state pull\nEOF",
    "cat 'unbalanced x.tfstate",
    # Earlier guard rules still deny.
    "print" + "env",
    "cat ~/.netrc",
    "echo $GITHUB_" + "TOKEN",
]

fails = 0
for cmd in ALLOW:
    r = hook.detect(cmd)
    if r is not None:
        fails += 1
        print(f"FAIL allow: {cmd!r} -> {r}")
for cmd in DENY:
    r = hook.detect(cmd)
    if r is None:
        fails += 1
        print(f"FAIL deny: {cmd!r} passed")

event = json.dumps({"tool_name": "Bash", "tool_input": {"command": "cat terraform.tfstate"}})
out = subprocess.run([sys.executable, "-I", str(HOOK)], input=event, capture_output=True, text=True).stdout
if '"permissionDecision": "deny"' not in out:
    fails += 1
    print(f"FAIL end-to-end deny output: {out!r}")

print(f"{len(ALLOW)} allow, {len(DENY)} deny, 1 end-to-end, {fails} failed")
sys.exit(1 if fails else 0)
