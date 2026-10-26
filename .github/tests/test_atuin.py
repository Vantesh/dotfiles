"""Exercise installed Atuin against clean homes through its real shell entry points."""

import json
import shlex
import shutil
from pathlib import Path

import pytest
from helpers import CHEZMOI, ROOT, SCRIPTS
from test_setup import env as env
from test_setup import run_setup, stub

ATUIN = shutil.which("atuin")
FISH = shutil.which("fish")


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
    config = Path(env.get("XDG_CONFIG_HOME", tmp_path / ".config")) / "atuin"
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
{shlex.quote(ATUIN)} config get --resolved logs.dir > "$HOME/log-path"
{shlex.quote(ATUIN)} config get --resolved daemon.socket_path > "$HOME/socket-path"
{shlex.quote(ATUIN)} config get --resolved daemon.pidfile_path > "$HOME/pid-path"
"""
    source = tmp_path / "source"
    scripts = source / ".chezmoiscripts/linux"
    scripts.mkdir(parents=True)
    templates = source / ".chezmoitemplates/lib"
    templates.mkdir(parents=True)
    shutil.copy(ROOT / "home/.chezmoitemplates/lib/common.sh", templates / "common.sh")
    shutil.copytree(ROOT / "home/dot_config/private_atuin", source / "dot_config/private_atuin")
    shutil.copy(ROOT / "home/.chezmoiignore.tmpl", source / ".chezmoiignore.tmpl")
    shutil.copy(SCRIPTS / "run_onchange_after_10_atuin.sh.tmpl", scripts)
    install = shutil.which("install")
    assert install is not None
    (Path(env["PATH"]) / "install").symlink_to(install)
    # Keep authentication outside this path test. The setup variant performs
    # its first real native settings load exactly where the hook invokes Atuin.
    stub(
        env, "atuin", '[ "$1" = status ] || exit 97\n' + (inspect if entry == "setup" else "exit 0")
    )
    chezmoi_config = tmp_path / "chezmoi.json"
    chezmoi_config.write_text(json.dumps({"data": {"personal": True, "distroFamily": "arch"}}))
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
        assert not (tmp_path / ".config/atuin").exists()
    before = managed.stat().st_mtime_ns
    repeated = run_setup(env, command)
    assert repeated.returncode == 0, repeated.stderr
    assert managed.stat().st_mtime_ns == before
    if entry == "fish":
        native = Path(env["PATH"]) / "atuin"
        native.unlink()
        native.symlink_to(ATUIN)
        conf = ROOT / "home/dot_config/private_fish/conf.d/atuin.fish"
        result = run_setup(
            env,
            [
                FISH,
                "--no-config",
                "--interactive",
                "--command",
                f"source {shlex.quote(str(conf))}; functions -q _atuin_search; or exit 97; {inspect}",
            ],
        )
    else:
        result = applied
    assert result.returncode == 0, result.stderr
    info = (tmp_path / "info").read_text()
    assert f'client config: "{config / "config.toml"}"' in info
    assert f"client db path: {data / 'history.db'}" in info
    assert (data / "history.db").is_file()
    assert (data / "records.db").is_file()
    assert (tmp_path / "log-path").read_text().strip() == str(state)
    assert (tmp_path / "socket-path").read_text().strip() == str(runtime / "atuin.sock")
    assert (tmp_path / "pid-path").read_text().strip() == str(runtime / "atuin.pid")
    assert not (tmp_path / ".atuin").exists()
