"""Temporary homes, command stubs, and isolated setup-template rendering."""

import json
import re
import shlex
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path
from typing import override

ROOT = Path(__file__).resolve().parents[2]
LIB = ROOT / "home/.chezmoitemplates/lib"
SCRIPTS = ROOT / "home/.chezmoiscripts/linux"
CHEZMOI = shutil.which("chezmoi")


class ScriptCase(unittest.TestCase):
    directory: Path
    bin: Path
    calls: Path
    env: dict[str, str]

    @override
    def __str__(self) -> str:
        return self._testMethodName.removeprefix("test_").replace("_", " ").capitalize()

    @override
    def shortDescription(self) -> None:
        return None

    @override
    def setUp(self) -> None:
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.directory = Path(temporary.name)
        self.bin = self.directory / "bin"
        self.bin.mkdir()
        self.calls = self.directory / "calls"
        self.env = {
            "PATH": str(self.bin),
            "HOME": str(self.directory),
            "TMPDIR": str(self.directory),
            "CALLS": str(self.calls),
            "NO_COLOR": "1",
            **{
                f"XDG_{name}_HOME": str(self.directory / name.lower())
                for name in ("CONFIG", "DATA", "CACHE", "STATE")
            },
        }
        # System operations are unavailable unless a test explicitly stubs them.
        for command in (
            "awk",
            "bash",
            "cat",
            "chmod",
            "cmp",
            "cp",
            "dirname",
            "env",
            "grep",
            "install",
            "mkdir",
            "mktemp",
            "mv",
            "readlink",
            "rm",
            "stat",
            "test",
            "touch",
        ):
            target = shutil.which(command)
            if target is None:
                raise FileNotFoundError(f"Required test utility not found: {command}")
            (self.bin / command).symlink_to(target)
        self.stub("sudo", 'echo "Unexpected sudo: $*" >&2; exit 97')

    def stub(self, name: str, body: str, *, log: bool = False) -> None:
        # Retained fixtures use single-line arguments without tabs.
        logging = (
            (f'printf "%s\\t" {shlex.quote(name)} "$@" >> "$CALLS"\nprintf "\\n" >> "$CALLS"\n')
            if log
            else ""
        )
        path = self.bin / name
        path.unlink(missing_ok=True)
        path.write_text("#!/bin/sh\n" + logging + body + "\n")
        path.chmod(0o755)

    def logged_calls(self) -> list[list[str]]:
        if not self.calls.exists():
            return []
        return [line.split("\t")[:-1] for line in self.calls.read_text().splitlines()]

    def run_process(
        self, command: list[str], *, name: str, input: str | None = None
    ) -> subprocess.CompletedProcess[str]:
        try:
            return subprocess.run(
                command,
                cwd=self.directory,
                env=self.env,
                input=input,
                capture_output=True,
                text=True,
                check=False,
                timeout=15,
            )
        except subprocess.TimeoutExpired:
            self.fail(f"{name} timed out after 15s")

    def shell(
        self, script: str, *, name: str = "shell fixture"
    ) -> subprocess.CompletedProcess[str]:
        path = self.directory / "fixture.sh"
        path.write_text(script)
        return self.run_process(["/bin/bash", str(path)], name=name)

    def libraries(self, *names: str) -> str:
        return "".join(f"source {shlex.quote(str(LIB / name))}\n" for name in names)

    def function(self, path: Path, name: str) -> str:
        match = re.search(
            rf"^{re.escape(name)}\(\) \{{\n.*?^\}}",
            path.read_text(),
            re.MULTILINE | re.DOTALL,
        )
        if match is None:
            self.fail(f"{path}: function {name!r} not found")
        return match.group() + "\n"

    def render(self, path: Path, *, personal: bool = True) -> str:
        if not CHEZMOI:
            self.skipTest("chezmoi is required for setup template rendering")
        config = self.directory / "chezmoi.json"
        config.write_text("{}")
        data = {
            "personal": personal,
            "distroFamily": "arch",
            "font": {"ui": {"name": "Fixture Sans", "size": 11}},
            "chezmoi": {
                "os": "linux",
                "osRelease": {"id": "arch"},
                "workingTree": str(ROOT),
                "homeDir": str(self.directory),
            },
        }
        result = self.run_process(
            [
                CHEZMOI,
                "--config",
                str(config),
                "--source",
                str(ROOT / "home"),
                "--destination",
                str(self.directory),
                "--working-tree",
                str(ROOT),
                "--override-data",
                json.dumps(data),
                "execute-template",
            ],
            name=str(path),
            input=path.read_text(),
        )
        self.assertEqual(result.returncode, 0, f"{path}: {result.stderr}")
        return result.stdout
