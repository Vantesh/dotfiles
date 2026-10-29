"""Validator failure reporting for missing tools and empty discovery."""

import subprocess
from pathlib import Path

import pytest
from helpers import ROOT


@pytest.mark.parametrize(
    ("discovery_output", "expected"),
    [
        (None, "pyrefly"),
        ("", "source coverage is incomplete"),
        (f"    {ROOT}/.github/tests/helpers.py", "source coverage is incomplete"),
    ],
)
def test_validator_rejects_missing_tools_and_empty_discovery(
    tmp_path: Path, discovery_output: str | None, expected: str
) -> None:
    marker = tmp_path / "pytest-called"
    for tool in ("ruff", "pyrefly", "pytest", "chezmoi", "bash", "shellcheck"):
        if tool == "pyrefly" and discovery_output is None:
            continue
        body = "exit 0"
        if tool == "pyrefly":
            body = f"printf '%s\\n' '{discovery_output}'"
        elif tool == "pytest":
            body = 'printf called > "$TOOL_CALLS"'
        executable = tmp_path / tool
        executable.write_text("#!/bin/sh\n" + body + "\n")
        executable.chmod(0o755)
    result = subprocess.run(
        ["/usr/bin/python3", "-B", str(ROOT / ".github/tests/validate.py")],
        env={"PATH": str(tmp_path), "TOOL_CALLS": str(marker)},
        capture_output=True,
        text=True,
        check=False,
        timeout=15,
    )
    assert result.returncode != 0
    assert expected.lower() in result.stderr.lower()
    if discovery_output is None:
        assert "installed separately" in result.stderr
    assert not marker.exists()
