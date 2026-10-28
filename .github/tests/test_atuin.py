"""Exercise installed Atuin against clean homes through its real shell entry points."""

import json
import shlex
import shutil
from pathlib import Path

import pytest
from helpers import CHEZMOI, ROOT, SCRIPTS
from test_setup import PYTHON, calls, render_python, run_setup, stub
from test_setup import env as env

ATUIN = shutil.which("atuin")
FISH = shutil.which("fish")
HOOK = "run_onchange_after_10_atuin.py"


@pytest.mark.parametrize("entry", ["fish", "setup"])
@pytest.mark.parametrize("custom_xdg", [False, True], ids=["defaults", "xdg"])
def test_first_atuin_launch_uses_separate_xdg_paths(
    env: dict[str, str], tmp_path: Path, entry: str, custom_xdg: bool
) -> None:
    if ATUIN is None or FISH is None:
        pytest.skip("Native Atuin/Fish integration requires atuin and fish on PATH")
    assert CHEZMOI is not None
    if not custom_xdg:
        for name in ("CONFIG", "DATA", "STATE", "CACHE"):
            env.pop(f"XDG_{name}_HOME")
    config = tmp_path / ".config/atuin"
    data = Path(env.get("XDG_DATA_HOME", tmp_path / ".local/share")) / "atuin"
    state = Path(env.get("XDG_STATE_HOME", tmp_path / ".local/state")) / "atuin"
    runtime = tmp_path / "runtime"
    runtime.mkdir(mode=0o700)
    env.update(
        XDG_RUNTIME_DIR=str(runtime),
        TERM="dumb",
        ATUIN_AUTO_SYNC="false",
        ATUIN_DAEMON__AUTOSTART="false",
    )
    # Native settings inspection initializes the real stores without login or a daemon.
    inspect = f"""{shlex.quote(ATUIN)} info > "$HOME/info"
{shlex.quote(ATUIN)} config get --resolved key_path > "$HOME/key-path"
{shlex.quote(ATUIN)} config get --resolved logs.dir > "$HOME/log-path"
{shlex.quote(ATUIN)} config get --resolved daemon.socket_path > "$HOME/socket-path"
{shlex.quote(ATUIN)} config get --resolved daemon.pidfile_path > "$HOME/pid-path"
"""
    source = tmp_path / "source"
    scripts = source / ".chezmoiscripts/linux"
    scripts.mkdir(parents=True)
    shutil.copytree(ROOT / "home/.chezmoitemplates/lib", source / ".chezmoitemplates/lib")
    shutil.copytree(ROOT / "home/dot_config/private_atuin", source / "dot_config/private_atuin")
    shutil.copy(ROOT / "home/.chezmoiignore.tmpl", source / ".chezmoiignore.tmpl")
    shutil.copy(SCRIPTS / HOOK, scripts)
    # Keep authentication outside this path test. The setup variant performs
    # its first real native settings load exactly where the hook invokes Atuin.
    stub(
        env, "atuin", '[ "$1" = status ] || exit 97\n' + (inspect if entry == "setup" else "exit 0")
    )
    chezmoi_config = tmp_path / "chezmoi.json"
    chezmoi_config.write_text(
        json.dumps(
            {
                "data": {"personal": True, "distroFamily": "arch"},
                "scriptEnv": {"DOTFILES_PERSONAL_ENABLED": "1"},
            }
        )
    )
    command = [
        CHEZMOI,
        "--config",
        str(chezmoi_config),
        "--source",
        str(source),
        "--destination",
        str(tmp_path),
        "--no-tty",
        "apply",
    ]
    applied = run_setup(env, command)
    assert applied.returncode == 0, applied.stderr
    managed = config / "config.toml"
    assert (
        managed.read_text()
        == (ROOT / "home/dot_config/private_atuin/private_config.toml").read_text()
    )
    assert managed.stat().st_mode & 0o777 == 0o600
    assert config.stat().st_mode & 0o777 == 0o700
    if custom_xdg:
        assert not (Path(env["XDG_CONFIG_HOME"]) / "atuin/config.toml").exists()
    before = managed.stat().st_mtime_ns
    repeated = run_setup(env, command)
    assert repeated.returncode == 0, repeated.stderr
    assert managed.stat().st_mtime_ns == before
    if entry == "fish":
        native = Path(env["PATH"]) / "atuin"
        native.unlink()
        native.symlink_to(ATUIN)
        conf = ROOT / "home/dot_config/private_fish/conf.d/atuin.fish"
        launch = [
            FISH,
            "--no-config",
            "--interactive",
            "--command",
            f"source {shlex.quote(str(conf))}; functions -q _atuin_search; or exit 97; {inspect}",
        ]
    else:
        launch = [PYTHON, "-B", str(render_python(env, HOOK, source=source))]
    for _ in range(2):
        result = run_setup(env, launch)
        assert result.returncode == 0, result.stderr
        info = (tmp_path / "info").read_text()
        assert f'client config: "{config / "config.toml"}"' in info
        assert f"client db path: {data / 'history.db'}" in info
        assert (data / "history.db").is_file()
        assert (data / "records.db").is_file()
        assert (tmp_path / "key-path").read_text().strip() == str(data / "key")
        assert (tmp_path / "log-path").read_text().strip() == str(state)
        assert (tmp_path / "socket-path").read_text().strip() == str(runtime / "atuin.sock")
        assert (tmp_path / "pid-path").read_text().strip() == str(runtime / "atuin.pid")
        assert f'ATUIN_HOME = "{config}"' in info
        assert f'ATUIN_CONFIG_DIR = "{config}"' in info
        assert not (tmp_path / ".atuin").exists()


@pytest.fixture
def atuin_setup(env: dict[str, str], tmp_path: Path) -> list[str]:
    script = render_python(env, HOOK)
    config = tmp_path / ".config/atuin/config.toml"
    config.parent.mkdir(parents=True)
    shutil.copy(ROOT / "home/dot_config/private_atuin/private_config.toml", config)
    # Synthetic fields include whitespace, Unicode, quotes, CRLF and an intentional
    # final newline. The native CLI must receive them unchanged, without logs.
    credentials = {
        "username": "fixture-user-Ω",
        "password": " secret-password-fixture ' \\ $()\r\nend ",
        "atuin_key": " secret-key-fixture\nwith-newline\n",
    }
    (tmp_path / "vault.json").write_text(json.dumps(credentials))
    commands = Path(env["PATH"])
    (commands / "rbw").write_text(r"""#!/usr/bin/python3 -B
import json, os, sys
from pathlib import Path
home = Path(os.environ["HOME"])
with Path(os.environ["CALLS"]).open("a") as stream:
    stream.write("rbw\t" + "\t".join(sys.argv[1:]) + "\t\n")
assert sys.argv[1:3] == ["get", "--field"] and sys.argv[4] == "Atuin"
fields = json.loads((home / "vault.json").read_text())
if os.environ.get("VAULT_STATUS"):
    print(fields["password"], file=sys.stderr)
    sys.exit(int(os.environ["VAULT_STATUS"]))
sys.stdout.buffer.write(fields[sys.argv[3]].encode("utf-8") + b"\n")
""")
    (commands / "atuin").write_text(r"""#!/usr/bin/python3 -B
import json, os, sys
from pathlib import Path
home = Path(os.environ["HOME"])
action = sys.argv[1]
# Never record the credential-bearing argv, even in the test call log.
with Path(os.environ["CALLS"]).open("a") as stream:
    stream.write("atuin\t" + action + "\t\n")
if action == "status":
    sys.exit(0 if (home / "logged-in").exists() else 1)
if action == "login":
    fields = json.loads((home / "vault.json").read_text())
    expected = ["--username", fields["username"], "--password", fields["password"], "--key", fields["atuin_key"]]
    if sys.argv[2:] != expected:
        sys.exit(99)
    # Native failure output is deliberately unsafe; the hook must suppress it.
    if os.environ.get("LOGIN_STATUS"):
        print(fields["password"])
        print(fields["atuin_key"], file=sys.stderr)
        sys.exit(int(os.environ["LOGIN_STATUS"]))
    (home / "logged-in").touch()
elif action == "sync":
    sys.exit(int(os.environ.get("SYNC_STATUS", "0")))
else:
    sys.exit(97)
""")
    for name in ("atuin", "rbw"):
        (commands / name).chmod(0o755)
    return [PYTHON, "-B", str(script)]


def test_personal_login_retains_vault_fields_and_syncs_only_after_login(
    env: dict[str, str], tmp_path: Path, atuin_setup: list[str]
) -> None:
    first = run_setup(env, atuin_setup)
    assert first.returncode == 0, first.stderr
    assert calls(env) == [
        ["atuin", "status"],
        ["rbw", "get", "--field", "username", "Atuin"],
        ["rbw", "get", "--field", "password", "Atuin"],
        ["rbw", "get", "--field", "atuin_key", "Atuin"],
        ["atuin", "login"],
        ["atuin", "sync"],
    ]
    repeated = run_setup(env, atuin_setup)
    assert repeated.returncode == 0, repeated.stderr
    assert repeated.stdout == repeated.stderr == ""
    assert calls(env)[-1] == ["atuin", "status"]
    assert calls(env).count(["atuin", "login"]) == 1
    assert calls(env).count(["atuin", "sync"]) == 1
    log = (tmp_path / "state/chezmoi/logs/setup.log").read_text()
    for secret in ("secret-password-fixture", "secret-key-fixture", "fixture-user-Ω"):
        assert secret not in log + first.stdout + first.stderr + repeated.stderr


@pytest.mark.parametrize(
    "failure,status", [("VAULT_STATUS", 23), ("LOGIN_STATUS", 24), ("SYNC_STATUS", 25)]
)
def test_atuin_failures_stop_safely_without_recording_credentials(
    env: dict[str, str], tmp_path: Path, atuin_setup: list[str], failure: str, status: int
) -> None:
    env[failure] = str(status)
    result = run_setup(env, atuin_setup)
    assert result.returncode == status, result.stderr
    assert f"exit {status}" in result.stderr
    log = (tmp_path / "state/chezmoi/logs/setup.log").read_text()
    for secret in ("secret-password-fixture", "secret-key-fixture", "fixture-user-Ω"):
        assert secret not in log + result.stdout + result.stderr
    if failure == "VAULT_STATUS":
        assert ["atuin", "login"] not in calls(env)
    if failure != "SYNC_STATUS":
        assert ["atuin", "sync"] not in calls(env)


def test_missing_managed_config_fails_before_atuin_creates_defaults(
    env: dict[str, str], tmp_path: Path, atuin_setup: list[str]
) -> None:
    (tmp_path / ".config/atuin/config.toml").unlink()
    result = run_setup(env, atuin_setup)
    assert result.returncode == 1
    assert "apply managed files first" in result.stderr
    assert calls(env) == []
    assert not (tmp_path / ".atuin").exists()
