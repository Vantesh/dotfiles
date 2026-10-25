"""Render setup templates and check shell and managed Python syntax."""

import json
import shutil
import subprocess
import sys
import tomllib
from pathlib import Path
from typing import cast

from helpers import LIB, ROOT, SCRIPTS, ScriptCase


def main():
    required = ("ruff", "basedpyright", "pytest", "chezmoi", "bash")
    missing = [tool for tool in required if shutil.which(tool) is None]
    # ShellCheck also runs inside a fixture whose PATH contains only test utilities.
    shellcheck = shutil.which("shellcheck")
    if missing or shellcheck is None:
        if shellcheck is None:
            missing.append("shellcheck")
        raise SystemExit(
            f"Missing validation tools: {', '.join(missing)}. "
            + "These must be installed separately before running validation."
        )
    subprocess.run(["ruff", "check", "."], cwd=ROOT, check=True)
    subprocess.run(["ruff", "format", "--check", "."], cwd=ROOT, check=True)
    checked = subprocess.run(
        ["basedpyright", "--outputjson"],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
    if checked.returncode:
        print(checked.stdout + checked.stderr, file=sys.stderr, end="")
        raise SystemExit(checked.returncode)
    report = cast("dict[str, object]", json.loads(checked.stdout))
    summary = cast("dict[str, object]", report["summary"])
    if summary["filesAnalyzed"] == 0:
        raise SystemExit(
            f"BasedPyright {report['version']} analyzed no Python files. "
            + "The installed checker must support the explicitly included hidden source directories; "
            + "see microsoft/pyright#11861. Manage the tool separately."
        )

    print(f"BasedPyright: {summary['filesAnalyzed']} Python files analyzed")

    fixture = ScriptCase()
    fixture.setUp()
    shell_count = lint_count = 0
    try:
        paths = sorted(SCRIPTS.rglob("*")) + sorted(LIB.glob("*.sh"))
        for path in paths:
            if path.suffix not in (".sh", ".tmpl"):
                continue
            sources: set[str] = set()
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
        rendered_modifiers: list[str] = []
        for path in sorted((ROOT / "home").rglob("*.tmpl")):
            if not path.read_text().startswith("#!/usr/bin/env python3"):
                continue
            for personal in (False, True):
                source = fixture.render(path, personal=personal)
                compile(source, str(path), "exec")
                for arguments in (("check",), ("format", "--check")):
                    subprocess.run(
                        [
                            "ruff",
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
                rendered = fixture.directory / f"{path.parent.name}-{personal}.py"
                _ = rendered.write_text(source)
                rendered_modifiers.append(str(rendered))
                modifier_count += 1
        subprocess.run(
            ["basedpyright", "--project", str(ROOT / "pyproject.toml"), *rendered_modifiers],
            cwd=ROOT,
            check=True,
        )
        mise_paths = sorted((ROOT / "mise").rglob("*.toml"))
        for path in mise_paths:
            tomllib.loads(path.read_text())
        print(f"Mise TOML syntax: {len(mise_paths)} files passed")
        print(
            f"Bash syntax and ShellCheck: {shell_count} shell sources/renderings passed "
            + f"({lint_count} distinct linted)"
        )
        print(
            f"Python syntax: {len(python_paths)} files and {modifier_count} modifier renderings passed"
        )
    finally:
        fixture.doCleanups()

    subprocess.run(["pytest", "-q"], cwd=ROOT, check=True)


if __name__ == "__main__":
    main()
