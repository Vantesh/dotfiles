"""Hermetic subprocess, real chezmoi rendering, and shell fixture helpers."""

import json
import re
import shlex
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LIB = ROOT / "home/.chezmoitemplates/lib"
SCRIPTS = ROOT / "home/.chezmoiscripts/linux"
CHEZMOI = shutil.which("chezmoi")
SHELLCHECK = shutil.which("shellcheck")
PYTHON3 = shutil.which("python3")


class ScriptCase(unittest.TestCase):
    def __str__(self):
        return self._testMethodName.removeprefix("test_").replace("_", " ").capitalize()

    def shortDescription(self):
        # Keep verbose results on one line instead of repeating the docstring.
        return None

    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.directory = Path(temporary.name)
        self.bin = self.directory / "bin"
        self.bin.mkdir()
        self.item = self.directory / "item"
        self.item.write_text("original")
        self.calls = self.directory / "calls"
        self.env = {
            "PATH": f"{self.bin}:/usr/bin:/bin",
            "HOME": str(self.directory),
            "TMPDIR": str(self.directory),
            **{
                f"XDG_{name}_HOME": str(self.directory / name.lower())
                for name in ("CONFIG", "DATA", "CACHE", "STATE")
            },
            "XDG_RUNTIME_DIR": str(self.directory / "runtime"),
            "ITEM": str(self.item),
            "CALLS": str(self.calls),
            "NO_COLOR": "1",
        }
        for command in (
            "sudo",
            "systemctl",
            "mount",
            "umount",
            "mountpoint",
            "swapon",
            "lsblk",
            "findmnt",
            "ya",
            "btrfs",
            "mise",
            "rbw",
            "curl",
            "git",
            "pacman",
            "updatedb",
        ):
            self.stub(command, 'echo "Unexpected system command: $0 $*" >&2; exit 97')

    def stub(self, name, body, *, log=False):
        # Count-prefixed NUL records preserve empty args and embedded newlines.
        logging = (
            ('printf "%s\\0" ' + shlex.quote(name) + ' "$#" "$@" >> "$CALLS"\n')
            if log
            else ""
        )
        path = self.bin / name
        path.write_text("#!/bin/sh\n" + logging + body + "\n")
        path.chmod(0o755)

    def logged_calls(self):
        if not self.calls.exists():
            return []
        fields = iter(self.calls.read_text().split("\0")[:-1])
        calls = []
        for name in fields:
            count = int(next(fields))
            calls.append([name, *(next(fields) for _ in range(count))])
        return calls

    def run_process(self, command, *, name, input=None, env=None):
        try:
            return subprocess.run(
                command,
                cwd=self.directory,
                env=self.env if env is None else env,
                input=input,
                capture_output=True,
                text=True,
                timeout=15,
            )
        except subprocess.TimeoutExpired as error:
            self.fail(f"{name} timed out after {error.timeout}s")

    def shell(self, script, *, name="shell fixture"):
        # Fragments have no production prologue; do not silently add errexit/nounset.
        if not script.startswith("#!"):
            script = "#!/usr/bin/env bash\n" + script
        path = self.directory / "fixture-script"
        path.write_text(script)
        interpreter = shlex.split(script.splitlines()[0][2:])
        return self.run_process([*interpreter, str(path)], name=name)

    def function(self, path, name, *, source=None):
        # Production functions close at column zero; nested blocks are indented.
        pattern = (
            rf"^(?:function\s+{re.escape(name)}(?:\s*\(\s*\))?|"
            rf"{re.escape(name)}\s*\(\s*\))\s*\{{\n.*?^\}}"
        )
        match = re.search(
            pattern, path.read_text() if source is None else source, re.M | re.S
        )
        if match is None:
            self.fail(
                f"{path}: function {name!r} not found (expected a brace-bodied shell function)"
            )
        return match.group()

    def fixture_data(self):
        return {
            "personal": False,
            "distroFamily": "arch",
            "setupSnapper": True,
            "setupHibernation": True,
            "installDrivers": True,
            "font": {"ui": {"name": "Fixture Sans", "size": 11}},
            "chezmoi": {
                "os": "linux",
                "osRelease": {"id": "arch"},
                "workingTree": str(ROOT),
                "homeDir": str(self.directory),
            },
        }

    def render(self, path, *, data=None, source=None, env=None):
        config = self.directory / "chezmoi.json"
        config.write_text("{}")
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
                json.dumps(self.fixture_data() if data is None else data),
                "execute-template",
            ],
            name=str(path),
            input=path.read_text() if source is None else source,
            env=env,
        )
        self.assertEqual(
            result.returncode, 0, f"{path}: rendering failed:\n{result.stderr}"
        )
        return result.stdout
