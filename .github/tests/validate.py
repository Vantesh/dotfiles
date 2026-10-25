"""Render setup templates and check shell and managed Python syntax."""

import shutil
import subprocess
import tomllib
from pathlib import Path

from helpers import CHEZMOI, LIB, ROOT, SCRIPTS, ScriptCase


def main():
    shellcheck = shutil.which("shellcheck")
    ruff = shutil.which("ruff")
    if not CHEZMOI or not shellcheck or not ruff:
        raise SystemExit("Validation requires chezmoi, Bash, ShellCheck, and Ruff on PATH")
    subprocess.run([ruff, "check", "--no-cache", "."], cwd=ROOT, check=True)
    subprocess.run([ruff, "format", "--no-cache", "--check", "."], cwd=ROOT, check=True)

    fixture = ScriptCase()
    fixture.setUp()
    shell_count = lint_count = 0
    try:
        paths = sorted(SCRIPTS.rglob("*")) + sorted(LIB.glob("*.sh"))
        for path in paths:
            if path.suffix not in (".sh", ".tmpl"):
                continue
            sources = set()
            for personal in (False, True) if path.suffix == ".tmpl" else (False,):
                source = (
                    fixture.render(path, personal=personal)
                    if path.suffix == ".tmpl"
                    else path.read_text()
                )
                shell_count += 1
                if source in sources:
                    continue
                sources.add(source)
                for command in (["/bin/bash", "-n"], [shellcheck, "--shell=bash", "-"]):
                    result = fixture.run_process(command, input=source, name=str(path))
                    if result.returncode:
                        raise SystemExit(
                            f"{path} (personal={personal}):\n{result.stdout}{result.stderr}"
                        )
                lint_count += 1
        python_paths = sorted((ROOT / "home").rglob("*.py")) + sorted(
            Path(__file__).parent.rglob("*.py")
        )
        for path in python_paths:
            compile(path.read_text(), str(path), "exec")
        # Chezmoi's Python modifiers need rendering before Ruff can parse them.
        modifier_count = 0
        for path in sorted((ROOT / "home").rglob("*.tmpl")):
            if not path.read_text().startswith("#!/usr/bin/env python3"):
                continue
            for personal in (False, True):
                source = fixture.render(path, personal=personal)
                compile(source, str(path), "exec")
                for arguments in (("check",), ("format", "--check")):
                    subprocess.run(
                        [
                            ruff,
                            *arguments,
                            "--no-cache",
                            "--stdin-filename",
                            str(path.with_suffix(".py")),
                            "-",
                        ],
                        cwd=ROOT,
                        input=source,
                        text=True,
                        check=True,
                    )
                modifier_count += 1
        mise_paths = sorted((ROOT / "mise").rglob("*.toml"))
        for path in mise_paths:
            tomllib.loads(path.read_text())
        print(f"Mise TOML syntax: {len(mise_paths)} files passed")
        print(
            f"Bash syntax and ShellCheck: {shell_count} shell sources/renderings passed "
            f"({lint_count} distinct linted)"
        )
        print(
            f"Python syntax: {len(python_paths)} files and {modifier_count} modifier renderings passed"
        )
    finally:
        fixture.doCleanups()


if __name__ == "__main__":
    main()
