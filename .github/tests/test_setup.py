"""Fresh profiles and bootstrap behavior, with system operations confined to a private home."""

import json
import os
import pty
import select
import shlex
import shutil
import subprocess
from pathlib import Path
from typing import cast

import pytest
from helpers import CHEZMOI, ROOT, SCRIPTS

PYTHON = "/usr/bin/python3"
BOOTSTRAP = ROOT / "home/.chezmoitemplates/bootstrap.py"


@pytest.fixture
def env(tmp_path: Path) -> dict[str, str]:
    commands = tmp_path / "bin"
    commands.mkdir()
    for name in ("bash", "cat", "chmod", "git", "ln", "python3", "sleep", "test", "touch"):
        executable = shutil.which(name)
        assert executable is not None, f"Required test utility not found: {name}"
        (commands / name).symlink_to(executable)
    env = {
        "PATH": str(commands),
        "HOME": str(tmp_path),
        "TMPDIR": str(tmp_path),
        "CALLS": str(tmp_path / "calls"),
        "NO_COLOR": "1",
        **{
            f"XDG_{name}_HOME": str(tmp_path / name.lower())
            for name in ("CONFIG", "DATA", "CACHE", "STATE")
        },
    }
    stub(env, "sudo", 'echo "Unexpected privileged operation: $*" >&2; exit 97')
    return env


def stub(env: dict[str, str], name: str, body: str, *, log: bool = False) -> None:
    path = Path(env["PATH"]) / name
    path.unlink(missing_ok=True)
    logging = (
        f'printf "%s\\t" {shlex.quote(name)} "$@" >> "$CALLS"\nprintf "\\n" >> "$CALLS"\n'
        if log
        else ""
    )
    path.write_text("#!/bin/sh\n" + logging + body + "\n")
    path.chmod(0o755)


def calls(env: dict[str, str]) -> list[list[str]]:
    path = Path(env["CALLS"])
    return (
        [line.split("\t")[:-1] for line in path.read_text().splitlines()] if path.exists() else []
    )


def run_setup(
    env: dict[str, str], command: list[str], *, input: str | None = None
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command,
        cwd=env["HOME"],
        env=env,
        input=input,
        capture_output=True,
        text=True,
        check=False,
        timeout=15,
    )


@pytest.fixture
def profile_command(tmp_path: Path) -> list[str]:
    assert CHEZMOI is not None, "chezmoi is required for profile validation"
    source = tmp_path / "source"
    source.mkdir()
    (source / ".chezmoi.yaml.tmpl").write_text((ROOT / "home/.chezmoi.yaml.tmpl").read_text())
    return [
        CHEZMOI,
        "--config",
        str(tmp_path / "chezmoi.yaml"),
        "--source",
        str(source),
        "--destination",
        str(tmp_path / "destination"),
        "--no-tty",
    ]


@pytest.mark.parametrize("personal", [False, True], ids=["nonpersonal", "personal"])
def test_fresh_profile_persists_only_its_personal_choice(
    env: dict[str, str], profile_command: list[str], personal: bool
) -> None:
    command = profile_command + ["--override-data", '{"chezmoi":{"osRelease":{"id":"arch"}}}']
    result = run_setup(
        env,
        command + ["init", "--promptBool", f"Is this a personal setup={str(personal).lower()}"],
    )
    assert result.returncode == 0, result.stderr
    result = run_setup(env, command + ["dump-config", "--format=json"])
    config = cast("dict[str, object]", json.loads(result.stdout))
    assert config["data"] == {"personal": personal, "distroFamily": "arch"}
    assert config["scriptEnv"] == {
        "PERSONAL": "1" if personal else "0",
        "DISTRO": "arch",
        "DISTRO_FAMILY": "arch",
    }
    env["NOCONFIRM"] = "1"
    result = run_setup(env, command + ["init"])
    assert result.returncode == 0, result.stderr
    repeated = run_setup(env, command + ["dump-config", "--format=json"])
    assert cast("dict[str, object]", json.loads(repeated.stdout))["data"] == config["data"]


@pytest.mark.parametrize(
    ("distro", "id_like", "accepted"),
    [("arch", "", True), ("cachyos", "arch", True), ("debian", "", False)],
)
def test_arch_family_support_is_explicit(
    env: dict[str, str],
    profile_command: list[str],
    tmp_path: Path,
    distro: str,
    id_like: str,
    accepted: bool,
) -> None:
    # init supplies native OS metadata; replace only that input to its real template.
    release = json.dumps(json.dumps({"id": distro, "idLike": id_like}))
    (tmp_path / "source/.chezmoi.yaml.tmpl").write_text(
        '{{- $_ := set .chezmoi "osRelease" (fromJson '
        + release
        + ") -}}\n"
        + (ROOT / "home/.chezmoi.yaml.tmpl").read_text()
    )
    result = run_setup(env, profile_command + ["init", "--promptDefaults"])
    assert (result.returncode == 0) == accepted, result.stdout + result.stderr
    if accepted:
        assert "personal: false" in (tmp_path / "chezmoi.yaml").read_text()


def test_nonpersonal_apply_is_isolated_and_idempotent(env: dict[str, str], tmp_path: Path) -> None:
    assert CHEZMOI is not None, "chezmoi is required for profile validation"
    env.update(NOCONFIRM="1", OFFLINE="1", CHEZMOI_SOURCE_DIR=str(ROOT / "home"))
    stub(env, "chezmoi", f'exec {shlex.quote(CHEZMOI)} "$@"')
    stub(env, "id", "echo 1000")
    stub(env, "yay", "exit 97")
    stub(env, "pacman", '[ "$1" = -Q ] || exit 127')
    stub(env, "pacman-conf", '[ "$*" = --repo-list ] || exit 97; echo chaotic-aur')
    stub(
        env,
        "sudo",
        """case "$*" in
    -v|'-n true'|'pacman -Syu --noconfirm') exit 0 ;;
    *) exit 97 ;;
esac""",
        log=True,
    )
    stub(
        env,
        "mise",
        '[ "$*" = "--env packages bootstrap packages apply --yes" ] || exit 97',
        log=True,
    )
    for command in (
        "rbw",
        "lspci",
        "hostnamectl",
        "systemctl",
        "gsettings",
        "sbctl",
        "findmnt",
        "busctl",
    ):
        stub(env, command, "exit 97", log=True)
    command = [
        CHEZMOI,
        "--config",
        str(tmp_path / "chezmoi.yaml"),
        "--source",
        str(ROOT),
        "--working-tree",
        str(ROOT),
        "--destination",
        str(tmp_path),
        "--no-tty",
        "--override-data",
        '{"chezmoi":{"osRelease":{"id":"arch"}}}',
    ]
    result = run_setup(env, command + ["init", "--data=false"])
    assert result.returncode == 0, result.stdout + result.stderr
    before = None
    for _ in range(2):
        result = run_setup(env, command + ["apply"])
        assert result.returncode == 0, result.stdout + result.stderr
        assert (tmp_path / ".config/fish/config.fish").is_file()
        assert not (tmp_path / ".ssh/id_rsa").exists()
        assert not (tmp_path / ".config/git/identity").exists()
        secrets = tmp_path / ".config/fish/conf.d/secrets.fish"
        assert "CHEZMOI_GITHUB_ACCESS_TOKEN" not in (
            secrets.read_text() if secrets.exists() else ""
        )
        verified = run_setup(env, command + ["verify", "--exclude=scripts"])
        assert verified.returncode == 0, verified.stderr
        current = {
            str(path.relative_to(tmp_path)): (path.read_bytes(), path.stat().st_mtime_ns)
            for path in (tmp_path / ".config").rglob("*")
            if path.is_file() and not path.is_symlink()
        }
        if before is not None:
            assert current == before
        before = current
    observed = calls(env)
    assert [call for call in observed if call[0] == "mise"] == [
        ["mise", "--env", "packages", "bootstrap", "packages", "apply", "--yes"]
    ]
    assert all(call[0] in ("sudo", "mise") for call in observed), observed


def secret_modifier(env: dict[str, str], personal: bool) -> list[str]:
    assert CHEZMOI is not None, "chezmoi is required for profile validation"
    home = Path(env["HOME"])
    config = home / "render.json"
    config.write_text("{}")
    rendered = run_setup(
        env,
        [
            CHEZMOI,
            "--config",
            str(config),
            "--source",
            str(ROOT / "home"),
            "--destination",
            str(home),
            "--override-data",
            json.dumps({"personal": personal}),
            "execute-template",
        ],
        input=(ROOT / "home/dot_config/spotifast/modify_settings.json.tmpl").read_text(),
    )
    assert rendered.returncode == 0, rendered.stderr
    script = home / "settings.py"
    script.write_text(rendered.stdout)
    return [PYTHON, "-B", str(script)]


@pytest.mark.parametrize("personal", [False, True], ids=["nonpersonal", "personal"])
def test_personal_secret_is_fetched_once_and_never_in_nonpersonal_mode(
    env: dict[str, str], personal: bool
) -> None:
    stub(
        env,
        "rbw",
        '[ "$*" = "get --field client_id spotify" ] || exit 97; echo fixture-client-id',
        log=True,
    )
    command = secret_modifier(env, personal)
    applied = run_setup(env, command, input="{}")
    assert applied.returncode == 0, applied.stderr
    settings = cast("dict[str, object]", json.loads(applied.stdout))
    assert settings.get("web_client_id") == ("fixture-client-id" if personal else None)
    repeated = run_setup(env, command, input=applied.stdout)
    assert repeated.returncode == 0, repeated.stderr
    assert repeated.stdout == applied.stdout
    assert calls(env) == ([["rbw", "get", "--field", "client_id", "spotify"]] if personal else [])


def test_secret_lookup_failure_does_not_publish_settings_or_private_errors(
    env: dict[str, str],
) -> None:
    stub(env, "rbw", "echo private-vault-canary >&2; exit 23")
    result = run_setup(env, secret_modifier(env, True), input="{}")
    assert result.returncode != 0
    assert result.stdout == ""
    assert "private-vault-canary" not in result.stderr
    assert "23" in result.stderr


@pytest.fixture
def bootstrap(env: dict[str, str], tmp_path: Path) -> list[str]:
    env.update(
        CHEZMOI_SOURCE_DIR=str(ROOT / "home"),
        PERSONAL="1",
        RBW_CONFIG=json.dumps({"email": "fixture@example.invalid", "lock_timeout": 10800}),
    )
    config = tmp_path / "config/rbw/config.json"
    config.parent.mkdir(parents=True)
    config.write_text(env["RBW_CONFIG"])
    stub(env, "pacman", "exit 0")
    stub(env, "mise", "exit 97")
    stub(
        env,
        "rbw",
        """case "$*" in
    'config show') printf '%s\\n' "$RBW_CONFIG"; exit "${RBW_CONFIG_STATUS:-0}" ;;
    'config set email fixture@example.invalid'|'config set lock_timeout 10800') exit 0 ;;
    login) printf '%s\\n' "${RBW_LOGIN_ERROR:-}" >&2; exit "${RBW_LOGIN_STATUS:-0}" ;;
    *) exit 97 ;;
esac""",
        log=True,
    )
    script = tmp_path / "bootstrap.sh"
    script.write_text((SCRIPTS / "run_before_00-install-pre-requisites.sh").read_text())
    return ["/bin/bash", str(script)]


def test_prerequisite_install_failure_stops_setup(
    env: dict[str, str], bootstrap: list[str]
) -> None:
    env["PERSONAL"] = "0"
    stub(env, "pacman", "exit 1")
    stub(env, "sudo", "exit 23", log=True)
    result = run_setup(env, bootstrap)
    assert result.returncode == 23, result.stderr
    assert len(calls(env)) == 1
    assert calls(env)[0][:3] == ["sudo", "pacman", "-S"]


def test_prerequisites_install_once_and_repeat_without_log_changes(
    env: dict[str, str], bootstrap: list[str], tmp_path: Path
) -> None:
    env.update(PERSONAL="0", INSTALLED=str(tmp_path / "installed"))
    (tmp_path / "bin/mise").unlink()
    stub(
        env,
        "pacman",
        """case "$*" in
    '-Q python'|'-Q python-loguru') exit 0 ;;
    '-Q git'|'-Q base-devel'|'-Q mise') test -f "$INSTALLED" ;;
    *) exit 97 ;;
esac""",
    )
    stub(
        env,
        "sudo",
        '''[ "$*" = 'pacman -S --needed --noconfirm -- git base-devel mise' ] || exit 97
touch "$INSTALLED"
printf '#!/bin/sh\\nexit 97\\n' > "$HOME/bin/mise"
chmod 755 "$HOME/bin/mise"''',
        log=True,
    )
    result = run_setup(env, bootstrap)
    assert result.returncode == 0, result.stderr
    assert (tmp_path / "installed").exists()
    log = tmp_path / "state/chezmoi/logs/setup.log"
    modified = log.stat().st_mtime_ns
    repeated = run_setup(env, bootstrap)
    assert repeated.returncode == 0, repeated.stderr
    assert repeated.stderr == ""
    assert log.stat().st_mtime_ns == modified
    assert calls(env) == [
        ["sudo", "pacman", "-S", "--needed", "--noconfirm", "--", "git", "base-devel", "mise"]
    ]


def test_personal_authentication_preserves_existing_configuration(
    env: dict[str, str], bootstrap: list[str]
) -> None:
    for _ in range(2):
        result = run_setup(env, bootstrap)
        assert result.returncode == 0, result.stderr
    assert calls(env) == [["rbw", "config", "show"], ["rbw", "login"]] * 2


@pytest.mark.parametrize("missing_command", [False, True], ids=["login-failure", "missing-rbw"])
def test_authentication_failures_preserve_status_and_private_diagnostics(
    env: dict[str, str], bootstrap: list[str], tmp_path: Path, missing_command: bool
) -> None:
    env.update(RBW_LOGIN_STATUS="23", RBW_LOGIN_ERROR="secret-token-canary")
    if missing_command:
        (tmp_path / "bin/rbw").unlink()
    result = run_setup(env, bootstrap)
    assert result.returncode == (1 if missing_command else 23), result.stderr
    diagnostics = (
        result.stdout + result.stderr + (tmp_path / "state/chezmoi/logs/setup.log").read_text()
    )
    assert "secret-token-canary" not in diagnostics
    assert "fixture@example.invalid" not in diagnostics
    assert "Traceback" not in diagnostics
    assert "\x1b[" not in result.stderr
    assert ("OS error 2" if missing_command else "23") in diagnostics
    assert calls(env) == ([] if missing_command else [["rbw", "config", "show"], ["rbw", "login"]])


def test_fresh_authentication_requires_an_email_and_supports_a_terminal(
    env: dict[str, str], bootstrap: list[str], tmp_path: Path
) -> None:
    (tmp_path / "config/rbw/config.json").unlink()
    env.update(RBW_CONFIG="{}", RBW_CONFIG_STATUS="1", NOCONFIRM="1")
    result = run_setup(env, bootstrap)
    assert result.returncode != 0
    assert "rbw config set email" in result.stderr
    Path(env["CALLS"]).unlink()
    env.pop("NOCONFIRM")
    master, slave = pty.openpty()
    try:
        os.write(master, b"fixture@example.invalid\n")
        result = subprocess.run(
            bootstrap,
            stdin=slave,
            cwd=tmp_path,
            env=env,
            capture_output=True,
            text=True,
            check=False,
            timeout=15,
        )
    finally:
        os.close(master)
        os.close(slave)
    assert result.returncode == 0, result.stderr
    assert calls(env) == [
        ["rbw", "config", "show"],
        ["rbw", "config", "set", "email", "fixture@example.invalid"],
        ["rbw", "config", "set", "lock_timeout", "10800"],
        ["rbw", "login"],
    ]


def test_unreadable_vault_configuration_is_not_reset(
    env: dict[str, str], bootstrap: list[str]
) -> None:
    env["RBW_CONFIG_STATUS"] = "23"
    result = run_setup(env, bootstrap)
    assert result.returncode == 23, result.stderr
    assert calls(env) == [["rbw", "config", "show"]]


def test_logs_are_lazy_private_and_bounded(
    env: dict[str, str], bootstrap: list[str], tmp_path: Path
) -> None:
    env["PERSONAL"] = "0"
    quiet = run_setup(env, bootstrap)
    assert quiet.returncode == 0, quiet.stderr
    assert quiet.stderr == "" and calls(env) == []
    assert not (tmp_path / "state/chezmoi/logs/setup.log").exists()
    code = """import runpy, sys
namespace = runpy.run_path(sys.argv[1])
namespace['configure_logging']()
for _ in range(7):
    namespace['logger'].debug('rotation-test ' + 'x' * (5 * 1024 * 1024))
namespace['logger'].remove()
"""
    result = run_setup(env, [PYTHON, "-B", "-c", code, str(BOOTSTRAP)])
    assert result.returncode == 0, result.stderr
    logs = tmp_path / "state/chezmoi/logs"
    assert logs.stat().st_mode & 0o777 == 0o700
    files = list(logs.glob("setup*.log"))
    assert len(files) == 6  # Current file and five archives.
    for path in files:
        assert path.stat().st_mode & 0o777 == 0o600
        assert path.stat().st_uid == os.getuid()
        with path.open("rb") as stream:
            assert b"rotation-test" in stream.read(200)


@pytest.mark.parametrize("no_color", [False, True], ids=["tty-color", "no-color-override"])
def test_terminal_color_respects_no_color(env: dict[str, str], no_color: bool) -> None:
    code = """import runpy, sys
namespace = runpy.run_path(sys.argv[1])
namespace['configure_logging']()
namespace['logger'].warning('terminal check')
"""
    env["TERM"] = "linux"
    if no_color:
        env["NO_COLOR"] = ""
    else:
        env.pop("NO_COLOR")
    master, slave = pty.openpty()
    try:
        result = subprocess.run(
            [PYTHON, "-B", "-c", code, str(BOOTSTRAP)],
            env=env,
            stdout=subprocess.PIPE,
            stderr=slave,
            check=False,
            timeout=15,
        )
        assert result.returncode == 0
        assert select.select([master], [], [], 2)[0], "No terminal diagnostic received"
        output = os.read(master, 4096).decode()
        assert "terminal check" in output
        assert ("\x1b[" in output) == (not no_color)
    finally:
        os.close(master)
        os.close(slave)


def test_symlinked_log_directory_is_rejected_before_bootstrap(
    env: dict[str, str], tmp_path: Path
) -> None:
    external = tmp_path / "external"
    external.mkdir()
    logs = tmp_path / "state/chezmoi/logs"
    logs.parent.mkdir(parents=True)
    logs.symlink_to(external, target_is_directory=True)
    stub(env, "pacman", "exit 0", log=True)
    result = run_setup(env, [PYTHON, "-B", str(BOOTSTRAP)])
    assert result.returncode != 0
    assert calls(env) == []
    assert list(external.iterdir()) == []


def test_fifo_log_file_does_not_block_or_allow_package_installation(
    env: dict[str, str], bootstrap: list[str], tmp_path: Path
) -> None:
    logs = tmp_path / "state/chezmoi/logs"
    logs.mkdir(parents=True)
    os.mkfifo(logs / "setup.log", 0o600)
    env["PERSONAL"] = "0"
    stub(
        env,
        "pacman",
        """case "$*" in
    '-Q python'|'-Q python-loguru') exit 0 ;;
    *) exit 1 ;;
esac""",
    )
    result = run_setup(env, bootstrap)
    assert result.returncode == 1, result.stderr
    assert "Traceback" not in result.stderr
    assert calls(env) == []
