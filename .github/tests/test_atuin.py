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
    config.mkdir(parents=True)
    shutil.copy(ROOT / "home/dot_config/private_atuin/private_config.toml", config / "config.toml")
    # Native settings inspection initializes the real stores without login or a daemon.
    inspect = f"""{shlex.quote(ATUIN)} info > "$HOME/info"
{shlex.quote(ATUIN)} config get --resolved logs.dir > "$HOME/log-path"
{shlex.quote(ATUIN)} config get --resolved daemon.socket_path > "$HOME/socket-path"
{shlex.quote(ATUIN)} config get --resolved daemon.pidfile_path > "$HOME/pid-path"
"""
    if entry == "fish":
        (Path(env["PATH"]) / "atuin").symlink_to(ATUIN)
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
        stub(env, "atuin", '[ "$1" = status ] || exit 97\n' + inspect)
        rendered = run_setup(
            env,
            [
                CHEZMOI,
                "--source",
                str(ROOT / "home"),
                "--override-data",
                json.dumps({"personal": True, "distroFamily": "arch"}),
                "execute-template",
            ],
            input=(SCRIPTS / "run_onchange_after_10_atuin.sh.tmpl").read_text(),
        )
        assert rendered.returncode == 0, rendered.stderr
        script = tmp_path / "atuin-setup.sh"
        script.write_text(rendered.stdout)
        result = run_setup(env, ["/bin/bash", str(script)])
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
