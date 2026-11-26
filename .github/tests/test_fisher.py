"""Fisher installs and updates from one immutable external assets pin."""

import os
import re
import shlex
import shutil
import subprocess
from pathlib import Path

import pytest
from helpers import CHEZMOI, ROOT

ASSETS = ROOT / "home/.chezmoidata/external_assets.yaml"
CONFIG = ROOT / "home/dot_config/private_fish/config.fish.tmpl"
PLUGINS = ROOT / "home/dot_config/private_fish/fish_plugins.tmpl"
COMMIT = re.compile(r"[0-9a-f]{40}")
FISH = shutil.which("fish")

pytestmark = pytest.mark.skipif(FISH is None, reason="fish is required for the bootstrap test")


def fisher_pin() -> tuple[str, str]:
    block = ASSETS.read_text().split("  fisher:\n", 1)[1].split("\n\n", 1)[0]
    version = re.search(r'version: "([^"]+)"', block)
    commit = re.search(r'commit: "([^"]+)"', block)
    assert version is not None and commit is not None
    return version[1], commit[1]


def render(tmp_path: Path, template: Path) -> str:
    assert CHEZMOI is not None, "chezmoi is required to render Fish templates"
    config = tmp_path / "chezmoi.json"
    config.write_text("{}")
    result = subprocess.run(
        [
            CHEZMOI,
            "--config",
            str(config),
            "--source",
            str(ROOT / "home"),
            "--working-tree",
            str(ROOT),
            "--destination",
            str(tmp_path),
            "execute-template",
        ],
        cwd=tmp_path,
        env={**os.environ, "HOME": str(tmp_path)},
        input=template.read_text(),
        capture_output=True,
        text=True,
        check=False,
        timeout=15,
    )
    assert result.returncode == 0, result.stderr
    return result.stdout


def test_fisher_pin_is_rendered_from_the_central_asset(tmp_path: Path) -> None:
    version, commit = fisher_pin()
    config = render(tmp_path, CONFIG)
    plugins = render(tmp_path, PLUGINS)

    assert f'set -l fisher_version "{version}"' in config
    assert f'set -l fisher_commit "{commit}"' in config
    assert plugins.splitlines()[0] == f"jorgebucaran/fisher@{commit}"
    for template in (CONFIG, PLUGINS):
        assert "{{ .externalAssets.fisher." in template.read_text()


def test_the_fisher_commit_is_declared_only_in_external_assets() -> None:
    _, commit = fisher_pin()
    owners = [
        path.relative_to(ROOT)
        for path in (ROOT / "home").rglob("*")
        if path.is_file() and commit in path.read_text(errors="ignore")
    ]
    assert COMMIT.fullmatch(commit)
    assert owners == [ASSETS.relative_to(ROOT)]


def bootstrap(
    tmp_path: Path, *, head: str, clone_fails: bool
) -> tuple[subprocess.CompletedProcess[str], list[list[str]]]:
    commands = tmp_path / "bin"
    commands.mkdir()
    for name in ("cat", "mkdir", "mktemp", "rm"):
        executable = shutil.which(name)
        assert executable is not None, f"Required test utility not found: {name}"
        (commands / name).symlink_to(executable)

    calls = tmp_path / "calls"
    git = commands / "git"
    git.write_text(
        """#!/bin/sh
printf '%s\\t' git "$@" >> "$CALLS"
printf '\\n' >> "$CALLS"
case " $* " in
  *" clone "*)
    test "${FISHER_CLONE_FAIL:-0}" = 1 && exit 1
    for last; do :; done
    mkdir -p "$last/functions"
    cat > "$last/functions/fisher.fish" <<'FISH'
function fisher
    printf '%s\\t' fisher $argv >> $CALLS
    printf '\\n' >> $CALLS
end
FISH
    ;;
  *" rev-parse "*) printf '%s\\n' "$FISHER_HEAD" ;;
esac
exit 0
"""
    )
    git.chmod(0o755)

    assert FISH is not None
    script = tmp_path / "config.fish"
    script.write_text(render(tmp_path, CONFIG))
    result = subprocess.run(
        [FISH, "-i", "-c", f"source {shlex.quote(str(script))}"],
        cwd=tmp_path,
        env={
            "PATH": str(commands),
            "HOME": str(tmp_path),
            "TMPDIR": str(tmp_path),
            "CALLS": str(calls),
            "FISHER_HEAD": head,
            "FISHER_CLONE_FAIL": "1" if clone_fails else "0",
            "NO_COLOR": "1",
        },
        capture_output=True,
        text=True,
        check=False,
        timeout=15,
    )
    log = (
        [line.split("\t")[:-1] for line in calls.read_text().splitlines()] if calls.exists() else []
    )
    return result, log


def test_bootstrap_verifies_the_tag_and_installs_the_pinned_commit(tmp_path: Path) -> None:
    version, commit = fisher_pin()
    result, log = bootstrap(tmp_path, head=commit, clone_fails=False)

    assert result.returncode == 0, result.stderr
    clone = next(call for call in log if call[:2] == ["git", "clone"])
    assert clone[clone.index("--branch") + 1] == version
    assert any(call[:2] == ["git", "-C"] and call[-2:] == ["rev-parse", "HEAD"] for call in log)
    install = next(call for call in log if call[0] == "fisher")
    assert install[1:] == ["install", f"jorgebucaran/fisher@{commit}"]


@pytest.mark.parametrize("case", ["mismatched-head", "failed-clone"])
def test_bootstrap_never_installs_unverified_code(tmp_path: Path, case: str) -> None:
    result, log = bootstrap(tmp_path, head="0" * 40, clone_fails=case == "failed-clone")

    assert result.returncode == 0
    assert "Fisher bootstrap failed verification; refusing to run unverified code." in result.stderr
    assert not any(call[0] == "fisher" for call in log)
