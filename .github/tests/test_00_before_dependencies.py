"""Retained application behavior and validator failure reporting."""

# runpy inspects dynamic application objects.
# pyright: reportAny=false

import os
import runpy
import subprocess
from pathlib import Path
from types import SimpleNamespace
from typing import override
from unittest.mock import MagicMock, patch

import pytest
from helpers import ROOT, ScriptCase


class PythonApplicationTests(ScriptCase):
    @override
    def setUp(self) -> None:
        super().setUp()
        # Only Kitty's embedded TUI imports are unavailable in the CI container.
        dependencies = {
            name: MagicMock()
            for name in (
                "kittens.tui.handler",
                "kittens.tui.line_edit",
                "kittens.tui.loop",
                "kittens.tui.operations",
                "kitty.config",
                "kitty.key_encoding",
                "kitty.typing_compat",
            )
        }
        dependencies["kittens.tui.handler"].Handler = object
        with patch.dict("sys.modules", dependencies):
            self.search = runpy.run_path(str(ROOT / "home/dot_config/kitty/search.py"))

    def test_kitty_search_rejects_bad_window_ids_before_remote_operations(self) -> None:
        self.stub("kitty", "exit 0", log=True)
        for arguments in (["search.py"], ["search.py", "invalid"]):
            with (
                self.subTest(arguments=arguments),
                patch.dict(os.environ, self.env, clear=True),
                self.assertRaises(SystemExit),
            ):
                self.search["main"](arguments)
        self.assertEqual(self.logged_calls(), [])

    def test_kitty_search_displays_marker_errors_and_recovers_after_editing(self) -> None:
        self.stub(
            "kitty",
            r"""if [ "$2" = create-marker ]; then
    echo 'Invalid regular expression' >&2; exit 23
fi""",
            log=True,
        )
        handler = self.search["Search"].__new__(self.search["Search"])
        handler.window_ids = [1]
        handler.line_edit = SimpleNamespace(current_input="[")
        handler.mode = "regex"
        handler.error = ""
        with patch.dict(os.environ, self.env, clear=True):
            handler.mark()
            self.assertIn("Invalid regular expression", handler.error)
            self.assertEqual(
                [call[2] for call in self.logged_calls()], ["create-marker", "remove-marker"]
            )
            self.stub("kitty", "exit 0")
            handler.line_edit.current_input = "valid"
            handler.mark()
            self.assertEqual(handler.error, "")


@pytest.mark.parametrize(
    ("checker_output", "expected"),
    [
        (None, "basedpyright"),
        (
            '{"version":"affected-release","summary":{"filesAnalyzed":0}}',
            "analyzed no Python files",
        ),
    ],
)
def test_validator_rejects_missing_tools_and_empty_discovery(
    tmp_path: Path, checker_output: str | None, expected: str
) -> None:
    marker = tmp_path / "pytest-called"
    for tool in ("ruff", "basedpyright", "pytest", "chezmoi", "bash", "shellcheck"):
        if tool == "basedpyright" and checker_output is None:
            continue
        body = "exit 0"
        if tool == "basedpyright":
            body = f"printf '%s\\n' '{checker_output}'"
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
    if checker_output is None:
        assert "installed separately" in result.stderr
    assert not marker.exists()
