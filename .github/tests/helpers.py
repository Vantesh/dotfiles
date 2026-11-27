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
LOGIN_MANAGER = ROOT / "home/.chezmoitemplates/login-manager"
CHEZMOI = shutil.which("chezmoi")


def renovate_version() -> str:
    """Read the Renovate version pinned by the CI workflow.

    The workflow is the single source of truth; Renovate's custom manager
    updates it, and local npx execution follows automatically.
    """
    workflow = (ROOT / ".github/workflows/ci-dots.yaml").read_text()
    match = re.search(r"renovate@(\d+\.\d+\.\d+)", workflow)
    if match is None:
        raise RuntimeError("CI workflow does not pin a Renovate version")
    return match.group(1)


def renovate_command(*arguments: str) -> list[str]:
    """Return the pinned Renovate command executed through npx."""
    npx = shutil.which("npx")
    if npx is None:
        raise RuntimeError("npx is required to run the Renovate tests; install Node.js and npm")
    return [
        npx,
        "--yes",
        f"--package=renovate@{renovate_version()}",
        "--",
        "renovate",
        *arguments,
    ]


def copy_login_manager(source: Path) -> None:
    """Add the greeter templates that both display-manager hooks depend on."""
    shutil.copytree(LOGIN_MANAGER, source / ".chezmoitemplates/login-manager", dirs_exist_ok=True)


class ScriptCase(unittest.TestCase):
    directory: Path
    bin: Path
    calls: Path
    env: dict[str, str]

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
            "CHEZMOI_SOURCE_DIR": str(ROOT / "home"),
            # Runtime scripts use /usr/bin/python3; expose Mise's development
            # Loguru to those subprocesses without a host Python package.
            "PYTHONPATH": str(next((ROOT / ".venv/lib").glob("python*/site-packages"), "")),
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
