"""Render and statically validate setup code without executing setup scripts."""

import shutil
from pathlib import Path

from helpers import CHEZMOI, LIB, SCRIPTS, ScriptCase


def main():
    shellcheck = shutil.which("shellcheck")
    if not CHEZMOI or not shellcheck:
        raise SystemExit("Validation requires chezmoi, Bash, and ShellCheck on PATH")

    fixture = ScriptCase()
    fixture.setUp()
    shell_count = 0
    try:
        paths = sorted(SCRIPTS.rglob("*")) + sorted(LIB.glob("*.sh"))
        for path in paths:
            if path.suffix not in (".sh", ".tmpl"):
                continue
            for personal in ((False, True) if path.suffix == ".tmpl" else (False,)):
                source = (
                    fixture.render(path, personal=personal)
                    if path.suffix == ".tmpl" else path.read_text()
                )
                for command in (["/bin/bash", "-n"], [shellcheck, "--shell=bash", "-"]):
                    result = fixture.run_process(command, input=source, name=str(path))
                    if result.returncode:
                        raise SystemExit(
                            f"{path} (personal={personal}):\n{result.stdout}{result.stderr}"
                        )
                shell_count += 1
        python_paths = sorted(LIB.glob("*.py")) + sorted(
            Path(__file__).parent.glob("*.py")
        )
        for path in python_paths:
            compile(path.read_text(), str(path), "exec")
        print(f"Bash syntax and ShellCheck: {shell_count} shell sources/renderings passed")
        print(f"Python syntax: {len(python_paths)} files passed")
    finally:
        fixture.doCleanups()


if __name__ == "__main__":
    main()
