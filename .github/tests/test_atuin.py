"""Exercise installed Atuin against clean homes through its real shell entry points."""

import json
import shutil
from pathlib import Path

import pytest
from helpers import ROOT
from test_setup import PYTHON, calls, render_python, run_setup
from test_setup import env as env

HOOK = "run_onchange_after_02_atuin.py"


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
