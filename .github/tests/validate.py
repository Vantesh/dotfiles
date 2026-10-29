"""Render setup templates and check shell and managed Python syntax."""

import shutil
import subprocess
import tomllib
from pathlib import Path

from helpers import LIB, ROOT, SCRIPTS, ScriptCase


def check_types(expected: list[Path], *, project: bool = False) -> None:
    arguments = ["--config", str(ROOT / "pyproject.toml")]
    if not project:
        arguments.extend(str(path) for path in expected)
    discovery = subprocess.run(
        ["pyrefly", "dump-config", "--max-files", "all", *arguments],
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=True,
    )
    covered = {
        Path(line.strip()).resolve()
        for line in discovery.stdout.splitlines()
        if line.startswith("    /") and line.strip().endswith(".py")
    }
    missing = set(expected) - covered
    if not expected or missing:
        raise SystemExit(
            "Pyrefly source coverage is incomplete; missing Python files: "
            + ", ".join(
                str(path.relative_to(ROOT)) if path.is_relative_to(ROOT) else str(path)
                for path in sorted(missing)
            )
        )
    subprocess.run(["pyrefly", "check", *arguments], cwd=ROOT, check=True)
    print(f"Pyrefly: {len(covered)} Python files covered")


def main():
    required = ("ruff", "pyrefly", "pytest", "chezmoi", "bash")
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
    source_paths = [
        path
        for directory in (SCRIPTS, LIB, Path(__file__).parent)
        for path in sorted(directory.rglob("*.py"))
        if not any(
            part in ("__pycache__", ".venv", ".pytest_cache", ".ruff_cache") for part in path.parts
        )
    ]
    check_types(source_paths, project=True)

    fixture = ScriptCase()
    fixture.setUp()
    shell_count = lint_count = 0
    try:
        paths = sorted(SCRIPTS.rglob("*")) + sorted(LIB.glob("*.sh"))
        for path in paths:
            if path.suffix not in (".sh", ".tmpl") or path.name.endswith(".py.tmpl"):
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
        # Render Python run scripts and settings modifiers before linting/type checking.
        template_count = raw_template_count = 0
        rendered_python: list[Path] = []
        for path in sorted((ROOT / "home").rglob("*.tmpl")):
            if not (
                path.name.endswith(".py.tmpl")
                or path.read_text().startswith("#!/usr/bin/env python3")
            ):
                continue
            variants = [
                (str(personal), fixture.render(path, personal=personal))
                for personal in (False, True)
            ]
            raw = path.read_text()
            if path.name.endswith(".py.tmpl") and all(
                "{{" not in line or line.lstrip().startswith("#") for line in raw.splitlines()
            ):
                variants.append(("source", raw))
            for variant, source in variants:
                compile(source, str(path), "exec")
                for arguments in (("check",), ("format", "--check")):
                    subprocess.run(
                        [
                            "ruff",
                            *arguments,
                            "--no-cache",
                            "--stdin-filename",
                            str(path.with_suffix("").with_suffix(".py")),
                            "-",
                        ],
                        cwd=ROOT,
                        input=source,
                        text=True,
                        check=True,
                    )
                relative = path.relative_to(ROOT).with_suffix("").with_suffix(".py")
                rendered = fixture.directory / "rendered" / variant / relative
                rendered.parent.mkdir(parents=True, exist_ok=True)
                _ = rendered.write_text(source)
                rendered_python.append(rendered)
                if variant == "source":
                    raw_template_count += 1
                else:
                    template_count += 1
        check_types(rendered_python)
        mise_paths = sorted((ROOT / "mise").rglob("*.toml"))
        for path in mise_paths:
            tomllib.loads(path.read_text())
        print(f"Mise TOML syntax: {len(mise_paths)} files passed")
        print(
            f"Bash syntax and ShellCheck: {shell_count} shell sources/renderings passed "
            + f"({lint_count} distinct linted)"
        )
        print(
            f"Python syntax: {len(python_paths)} files, {raw_template_count} unrendered templates "
            + f"and {template_count} Python template renderings passed"
        )
    finally:
        fixture.doCleanups()

    subprocess.run(["pytest", "-q"], cwd=ROOT, check=True)


if __name__ == "__main__":
    main()
