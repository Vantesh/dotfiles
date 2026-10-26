"""Fresh profiles and bootstrap behavior, with system operations confined to a private home."""

import json
import os
import pty
import re
import select
import shlex
import shutil
import subprocess
import tomllib
from pathlib import Path
from typing import cast

import pytest
from helpers import CHEZMOI, ROOT, SCRIPTS

PYTHON = "/usr/bin/python3"
AUTHENTICATION = "run_before_00_authentication.py"
PACKAGES = "run_onchange_before_02_packages.py.tmpl"
LOGGING = ROOT / "home/.chezmoitemplates/lib/provision_logging.py"


@pytest.fixture
def env(tmp_path: Path) -> dict[str, str]:
    commands = tmp_path / "bin"
    commands.mkdir()
    for name in ("bash", "cat", "chmod", "env", "git", "ln", "python3", "sleep", "test", "touch"):
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


def render_python(
    env: dict[str, str],
    name: str,
    *,
    personal: bool = True,
    distro: str = "arch",
    source: Path = ROOT / "home",
) -> Path:
    """Render a real workflow for focused subprocess and filesystem tests."""
    assert CHEZMOI is not None
    home = Path(env["HOME"])
    env.update(
        DOTFILES_PERSONAL_ENABLED="1" if personal else "0",
        CHEZMOI_SOURCE_DIR=str(source),
        CHEZMOI_WORKING_TREE=str(source.parent),
        CHEZMOI_OS_RELEASE_ID=distro,
    )
    if name.endswith(".py"):
        rendered = home / name
        shutil.copy(source / ".chezmoiscripts/linux" / name, rendered)
        return rendered
    config = home / "python-render.json"
    config.write_text("{}")
    result = run_setup(
        env,
        [
            CHEZMOI,
            "--config",
            str(config),
            "--source",
            str(source),
            "--working-tree",
            str(source.parent),
            "--destination",
            str(home),
            "--override-data",
            json.dumps(
                {
                    "personal": personal,
                    "distroFamily": "arch",
                    "chezmoi": {"osRelease": {"id": distro}},
                }
            ),
            "execute-template",
        ],
        input=(source / ".chezmoiscripts/linux" / name).read_text(),
    )
    assert result.returncode == 0, result.stderr
    rendered = home / name.removesuffix(".tmpl")
    rendered.write_text(result.stdout)
    return rendered


@pytest.mark.parametrize(
    "hook",
    [
        AUTHENTICATION,
        "run_onchange_before_01_sudo.py",
        "run_onchange_before_03_pacman.py.tmpl",
        "run_onchange_after_00_initramfs_config.py.tmpl",
        "run_onchange_after_04_quiet_boot.py.tmpl",
        "run_onchange_after_05_secure_boot.py.tmpl",
        "run_onchange_after_08_limine_theme.py.tmpl",
        "run_onchange_after_01_snapshots.py.tmpl",
        "run_onchange_after_03_hibernation.py.tmpl",
    ],
)
@pytest.mark.parametrize("profile", [None, "true", "0"], ids=["missing", "invalid", "disabled"])
def test_plain_personal_guards_precede_source_resolution_and_all_side_effects(
    env: dict[str, str], tmp_path: Path, hook: str, profile: str | None
) -> None:
    script = render_python(env, hook)
    env.pop("CHEZMOI_SOURCE_DIR")
    env.pop("DOTFILES_PERSONAL_ENABLED")
    if profile is not None:
        env["DOTFILES_PERSONAL_ENABLED"] = profile
    if profile is None:
        imported = run_setup(
            env,
            [PYTHON, "-B", "-c", "import runpy, sys; runpy.run_path(sys.argv[1])", str(script)],
        )
        assert imported.returncode == 0, imported.stderr
        assert imported.stdout == imported.stderr == ""
    result = run_setup(env, [PYTHON, "-B", str(script)])
    assert result.returncode == (0 if profile == "0" else 1)
    assert result.stdout == ""
    if profile == "0":
        assert result.stderr == ""
    else:
        assert "DOTFILES_PERSONAL_ENABLED must be '0' or '1'" in result.stderr
    assert not calls(env)
    assert not (tmp_path / "state").exists()


@pytest.mark.parametrize(
    "hook",
    [PACKAGES, "run_onchange_after_06_theming.py.tmpl", "run_onchange_after_14_services.py.tmpl"],
)
def test_environment_driven_workflows_reject_invalid_profiles_before_logging(
    env: dict[str, str], tmp_path: Path, hook: str
) -> None:
    script = render_python(env, hook)
    env["DOTFILES_PERSONAL_ENABLED"] = "true"
    result = run_setup(env, [PYTHON, "-B", str(script)])
    assert result.returncode == 1, result.stderr
    assert "DOTFILES_PERSONAL_ENABLED must be '0' or '1'" in result.stderr
    assert not calls(env)
    assert not (tmp_path / "state").exists()


def test_template_trigger_comments_keep_multiline_context_out_of_python(
    env: dict[str, str], tmp_path: Path
) -> None:
    source = tmp_path / 'source "quoted" \\ path\nUnicode 雪'
    scripts = source / ".chezmoiscripts/linux"
    scripts.mkdir(parents=True)
    shutil.copy(SCRIPTS / PACKAGES, scripts / PACKAGES)
    shutil.copytree(ROOT / "mise", source.parent / "mise")
    script = render_python(
        env, PACKAGES, personal=False, distro='arch\nraise RuntimeError("injected")', source=source
    )
    compile(script.read_text(), str(script), "exec")
    # Trigger values stay on comment lines; no statement is introduced.
    assert '\nraise RuntimeError("injected")' not in script.read_text()
    assert not calls(env)


@pytest.mark.parametrize("personal", [False, True], ids=["nonpersonal", "personal"])
def test_runtime_profile_and_rendered_exceptions_preserve_strings_and_types(
    env: dict[str, str], tmp_path: Path, personal: bool
) -> None:
    source = tmp_path / 'source "quoted" \' \\ newline\nUnicode 雪😀'
    scripts = source / ".chezmoiscripts/linux"
    scripts.mkdir(parents=True)
    name = "run_onchange_after_06_theming.py.tmpl"
    shutil.copy(SCRIPTS / name, scripts / name)
    data = source / ".chezmoidata"
    data.mkdir()
    font = "Font \"double\" 'single' \\ path\nUnicode 雪😀\u2028separator"
    (data / "font.json").write_text(json.dumps({"font": {"ui": {"name": font, "size": 11}}}))
    rendered = render_python(env, name, personal=personal, source=source)
    env.pop("CHEZMOI_SOURCE_DIR")
    # Load definitions only: no desktop settings or privileged operations run.
    result = run_setup(
        env,
        [
            PYTHON,
            "-B",
            "-c",
            """import json, runpy, sys
ns = runpy.run_path(sys.argv[1])
print(json.dumps({"personal": ns["PERSONAL"], "font": ns["FONT_NAME"]}))
""",
            str(rendered),
        ],
    )
    assert result.returncode == 0, result.stderr
    values = cast("dict[str, object]", json.loads(result.stdout))
    assert values["personal"] is personal
    assert values["font"] == f"{font} 11"
    assert not calls(env)


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
    assert cast("dict[str, object]", config["interpreters"])["py"] == {
        "command": PYTHON,
        "args": ["-B"],
    }
    assert config["scriptEnv"] == {
        "DOTFILES_PERSONAL_ENABLED": "1" if personal else "0",
        "DOTFILES_DISTRO_FAMILY": "arch",
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
        """case "$*" in
'--env packages bootstrap packages apply --yes'|'--quiet --env  bootstrap --only services,user --yes') exit 0 ;;
*) exit 97 ;;
esac""",
        log=True,
    )
    for command in (
        "rbw",
        "lspci",
        "hostnamectl",
        "sbctl",
        "findmnt",
        "busctl",
        "chsh",
    ):
        stub(env, command, "exit 97", log=True)
    stub(
        env,
        "gsettings",
        """[ "$1" = get ] || exit 97
case "$3" in
    font-name) echo "'SF Pro Text 12'" ;;
    button-layout) echo "':'" ;;
    default-zoom-level) echo "'small-plus'" ;;
    show-delete-permanently) echo true ;;
    *) exit 97 ;;
esac""",
        log=True,
    )
    stub(
        env,
        "systemctl",
        '[ "$1 $2" = "--user show" ] || exit 97; printf "LoadState=loaded\\nUnitFileState=static\\nActiveState=active\\n"',
        log=True,
    )
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
        for common in (
            "mimeapps.list",
            "qtengine/config.json",
            "gtk-3.0/gtk.css",
            "kitty/kitty.conf",
        ):
            assert (tmp_path / ".config" / common).is_file()
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
        ["mise", "--env", "packages", "bootstrap", "packages", "apply", "--yes"],
        ["mise", "--quiet", "--env", "", "bootstrap", "--only", "services,user", "--yes"],
    ]
    assert all(call[0] in ("sudo", "mise", "systemctl", "gsettings") for call in observed), observed
    assert all(call[1:3] == ["--user", "show"] for call in observed if call[0] == "systemctl")


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
        DOTFILES_PERSONAL_ENABLED="1",
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
    'config set email fixture@example.invalid') exit 0 ;;
    'config set lock_timeout 10800') exit "${RBW_LOCK_STATUS:-0}" ;;
    login) printf '%s\\n' "${RBW_LOGIN_ERROR:-}" >&2; exit "${RBW_LOGIN_STATUS:-0}" ;;
    *) exit 97 ;;
esac""",
        log=True,
    )
    script = tmp_path / "bootstrap.sh"
    script.write_text((SCRIPTS / "run_before_00-install-pre-requisites.sh").read_text())
    return ["/bin/bash", str(script)]


@pytest.fixture
def authentication(env: dict[str, str], bootstrap: list[str]) -> list[str]:
    assert bootstrap  # The shared fixture prepares the private vault commands.
    return [PYTHON, "-B", str(render_python(env, AUTHENTICATION))]


def test_prerequisite_install_failure_stops_setup(
    env: dict[str, str], bootstrap: list[str]
) -> None:
    env["DOTFILES_PERSONAL_ENABLED"] = "1"
    stub(env, "pacman", "exit 1")
    stub(env, "sudo", "exit 23", log=True)
    result = run_setup(env, bootstrap)
    assert result.returncode == 23, result.stderr
    assert len(calls(env)) == 1
    assert calls(env)[0][:3] == ["sudo", "pacman", "-S"]


@pytest.mark.parametrize("personal", [False, True], ids=["nonpersonal", "personal"])
def test_prerequisites_install_in_one_transaction_and_reapply_quietly(
    env: dict[str, str], bootstrap: list[str], tmp_path: Path, personal: bool
) -> None:
    env.update(
        DOTFILES_PERSONAL_ENABLED="1" if personal else "0", INSTALLED=str(tmp_path / "installed")
    )
    packages = ["python", "python-loguru", "git", "base-devel", "mise"]
    if personal:
        packages.extend(("rbw", "pinentry"))
    stub(env, "pacman", '[ "$1" = -Q ] && test -f "$INSTALLED"')
    install = ["pacman", "-S", "--needed", "--noconfirm", "--", *packages]
    stub(
        env,
        "sudo",
        f'[ "$*" = {shlex.quote(" ".join(install))} ] || exit 97\ntouch "$INSTALLED"',
        log=True,
    )
    first = run_setup(env, bootstrap)
    assert first.returncode == 0, first.stderr
    assert (tmp_path / "installed").exists()
    assert re.fullmatch(
        r"\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\] \[INFO\] Installing bootstrap dependencies\n",
        first.stderr,
    ), first.stderr
    repeated = run_setup(env, bootstrap)
    assert repeated.returncode == 0, repeated.stderr
    assert repeated.stderr == ""
    assert [call for call in calls(env) if call[0] == "sudo"] == [["sudo", *install]]
    assert not any(call[0] == "rbw" for call in calls(env))
    assert not (tmp_path / "state/chezmoi/logs/setup.log").exists()


def test_personal_authentication_preserves_existing_configuration(
    env: dict[str, str], authentication: list[str]
) -> None:
    for _ in range(2):
        result = run_setup(env, authentication)
        assert result.returncode == 0, result.stderr
    assert calls(env) == [["rbw", "config", "show"], ["rbw", "login"]] * 2


@pytest.mark.parametrize("missing_command", [False, True], ids=["login-failure", "missing-rbw"])
def test_authentication_failures_preserve_status_and_private_diagnostics(
    env: dict[str, str], authentication: list[str], tmp_path: Path, missing_command: bool
) -> None:
    env.update(RBW_LOGIN_STATUS="23", RBW_LOGIN_ERROR="secret-token-canary")
    if missing_command:
        (tmp_path / "bin/rbw").unlink()
    result = run_setup(env, authentication)
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
    env: dict[str, str], authentication: list[str], tmp_path: Path
) -> None:
    (tmp_path / "config/rbw/config.json").unlink()
    env.update(RBW_CONFIG="{}", RBW_CONFIG_STATUS="1", NOCONFIRM="1")
    result = run_setup(env, authentication)
    assert result.returncode != 0
    assert "rbw config set email" in result.stderr
    Path(env["CALLS"]).unlink()
    env.pop("NOCONFIRM")
    master, slave = pty.openpty()
    try:
        os.write(master, b"fixture@example.invalid\n")
        result = subprocess.run(
            authentication,
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
    env: dict[str, str], authentication: list[str]
) -> None:
    env["RBW_CONFIG_STATUS"] = "23"
    result = run_setup(env, authentication)
    assert result.returncode == 23, result.stderr
    assert calls(env) == [["rbw", "config", "show"]]


def test_python_bootstrap_is_quiet_and_logs_are_private_and_bounded(
    env: dict[str, str], tmp_path: Path
) -> None:
    env["DOTFILES_PERSONAL_ENABLED"] = "0"
    stub(env, "pacman", "exit 97", log=True)
    quiet = run_setup(env, [PYTHON, "-B", str(render_python(env, AUTHENTICATION, personal=False))])
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
    result = run_setup(env, [PYTHON, "-B", "-c", code, str(LOGGING)])
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
def test_terminal_color_and_log_locations(
    env: dict[str, str], tmp_path: Path, no_color: bool
) -> None:
    probe = tmp_path / "logging_probe.py"
    probe.write_text("""import sys
sys.path.insert(0, sys.argv[1])
from lib.provision_logging import configure_logging
from loguru import logger
configure_logging()
logger.warning('terminal check')
""")
    env["TERM"] = "linux"
    if no_color:
        env["NO_COLOR"] = ""
    else:
        env.pop("NO_COLOR")
    master, slave = pty.openpty()
    try:
        result = subprocess.run(
            [PYTHON, "-B", str(probe), str(LOGGING.parent.parent)],
            env=env,
            stdout=subprocess.PIPE,
            stderr=slave,
            check=False,
            timeout=15,
        )
        assert result.returncode == 0
        assert select.select([master], [], [], 2)[0], "No terminal diagnostic received"
        output = os.read(master, 4096).decode()
        assert ("\x1b[" in output) == (not no_color)
        plain = re.sub(r"\x1b\[[0-9;]*m", "", output).replace("\r\n", "\n")
        assert re.fullmatch(
            r"\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\] \[WARNING\] terminal check\n", plain
        ), plain
        persisted = (tmp_path / "state/chezmoi/logs/setup.log").read_text()
        assert re.fullmatch(
            r"\[\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\] \[WARNING\] "
            + r"\[logging_probe.py:6\] terminal check\n",
            persisted,
        ), persisted
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
    result = run_setup(env, [PYTHON, "-B", str(render_python(env, AUTHENTICATION))])
    assert result.returncode != 0
    assert calls(env) == []
    assert list(external.iterdir()) == []


def test_fifo_log_file_does_not_block_or_allow_package_installation(
    env: dict[str, str], authentication: list[str], tmp_path: Path
) -> None:
    logs = tmp_path / "state/chezmoi/logs"
    logs.mkdir(parents=True)
    os.mkfifo(logs / "setup.log", 0o600)
    env.update(DOTFILES_PERSONAL_ENABLED="1", RBW_LOGIN_STATUS="23")
    result = run_setup(env, authentication)
    assert result.returncode == 1, result.stderr
    assert "Traceback" not in result.stderr
    assert calls(env) == [["rbw", "config", "show"], ["rbw", "login"]]
    Path(env["CALLS"]).unlink()
    # An XDG failure must also remain concise when its file diagnostic cannot be written.
    gnupg = tmp_path / "data/gnupg"
    gnupg.parent.mkdir(parents=True)
    private = tmp_path / "private-key"
    private.write_text("private-file-canary")
    gnupg.symlink_to(private)
    failed = apply_packages(env)
    assert failed.returncode == 1, failed.stderr
    assert "Traceback" not in failed.stderr
    assert "private-file-canary" not in failed.stderr
    assert gnupg.read_text() == "private-file-canary"
    assert calls(env) == []


@pytest.fixture
def package_env(env: dict[str, str]) -> dict[str, str]:
    env.update(
        NOCONFIRM="1",
        OFFLINE="1",
        PACKAGES="linux 6.18-1\nlinux-headers 6.18-1",
        GPU="Intel Corporation [8086:1234]",
        DRIVER_VERSION="615.78.08",
        MISE_STATUS="0",
        UPGRADE_STATUS="0",
    )
    stub(env, "id", "echo 1000")
    stub(env, "yay", "exit 97")
    stub(env, "pacman-conf", "echo chaotic-aur")
    stub(
        env,
        "pacman",
        r"""case "$*" in
    '-Q chaotic-keyring chaotic-mirrorlist'|-Dk) exit 0 ;;
    '-T vulkan-driver') exit 127 ;;
    -Q) printf '%s\n' "$PACKAGES" ;;
    '-Q nvidia-utils') echo "nvidia-utils $DRIVER_VERSION-1" ;;
    '-Q nvidia-580xx-utils') echo "nvidia-580xx-utils $DRIVER_VERSION-1" ;;
    '-Qql linux') echo /usr/lib/modules/6.18-fixture/pkgbase ;;
    *) exit 97 ;;
esac""",
    )
    stub(
        env,
        "sudo",
        '''[ "$*" = 'pacman -Syu --noconfirm' ] || exit 97
exit "$UPGRADE_STATUS"''',
        log=True,
    )
    stub(env, "hostnamectl", "echo laptop")
    stub(env, "lspci", 'printf "01:00.0 VGA compatible controller [0300]: %s\n" "$GPU"')
    stub(env, "limine", "exit 97")
    stub(env, "mkinitcpio", "exit 97")
    stub(
        env,
        "modinfo",
        """case "$*" in
    '-k 6.18-fixture -F vermagic nvidia') echo '6.18-fixture SMP' ;;
    '-k 6.18-fixture -F version nvidia') echo "$DRIVER_VERSION" ;;
    *) exit 97 ;;
esac""",
    )
    stub(
        env,
        "mise",
        '''/usr/bin/python3 -B - <<'CHECK'
import json, os
from pathlib import Path
Path(os.environ['HOME'], 'observed.json').write_text(json.dumps({
    key: os.environ.get(key) for key in ('XDG_CONFIG_HOME', 'XDG_DATA_HOME', 'XDG_STATE_HOME',
        'GOPATH', 'CARGO_HOME', 'GNUPGHOME', 'MISE_ENV', 'MISE_CONFIG_FILE', 'OFFLINE', 'NOCONFIRM')}))
CHECK
[ "$?" = 0 ] || exit 98
exit "$MISE_STATUS"''',
        log=True,
    )
    return env


def apply_packages(
    env: dict[str, str], *, personal: bool = False, distro: str = "arch"
) -> subprocess.CompletedProcess[str]:
    return run_setup(
        env, [PYTHON, "-B", str(render_python(env, PACKAGES, personal=personal, distro=distro))]
    )


@pytest.mark.parametrize("raw_source", [False, True], ids=["rendered", "raw-python"])
def test_fresh_kvm_baseline_needs_no_vulkan_provider_or_personal_probes(
    package_env: dict[str, str], tmp_path: Path, raw_source: bool
) -> None:
    for name in ("lspci", "hostnamectl", "rbw", "systemctl", "sbctl"):
        stub(package_env, name, "exit 97", log=True)
    package_env.update(MISE_ENV="personal", MISE_CONFIG_FILE="/unrelated/config.toml")
    if raw_source:
        package_env.update(
            DOTFILES_PERSONAL_ENABLED="0",
            CHEZMOI_SOURCE_DIR=str(ROOT / "home"),
            CHEZMOI_OS_RELEASE_ID="arch",
        )
        result = run_setup(package_env, [PYTHON, "-B", str(SCRIPTS / PACKAGES)])
    else:
        result = apply_packages(package_env)
    assert result.returncode == 0, result.stderr
    assert "Installing baseline packages with Mise." in result.stderr
    recorded = calls(package_env)
    assert [call for call in recorded if call[0] == "mise"] == [
        ["mise", "--env", "packages", "bootstrap", "packages", "apply", "--yes"]
    ]
    assert all(call[0] in ("sudo", "mise") for call in recorded)
    observed = cast("dict[str, str | None]", json.loads((tmp_path / "observed.json").read_text()))
    assert observed["GOPATH"] == str(tmp_path / "data/go")
    assert not observed["MISE_ENV"] and not observed["MISE_CONFIG_FILE"]
    assert observed["OFFLINE"] == observed["NOCONFIRM"] == "1"
    for key in ("XDG_CONFIG_HOME", "XDG_DATA_HOME", "XDG_STATE_HOME", "GNUPGHOME"):
        assert Path(str(observed[key])).is_dir()
    assert (tmp_path / "data/gnupg").stat().st_mode & 0o777 == 0o700
    declarations = cast(
        "dict[str, dict[str, str | list[str]]]",
        tomllib.loads((ROOT / "mise/conf.d/packages.toml").read_text())["bootstrap"]["packages"],
    )
    # Protect the baseline policy, including transitive Vulkan demand from Zed.
    for name, declaration in declarations.items():
        if "zed" in name or "nvidia" in name:
            selected = declaration["env"]
            assert {"packages", "aur-helper"}.isdisjoint(
                [selected] if isinstance(selected, str) else selected
            ), name


def test_chaotic_trust_upgrade_and_helper_recover_then_reapply_without_duplicates(
    package_env: dict[str, str], tmp_path: Path
) -> None:
    (tmp_path / "bin/yay").unlink()
    stub(
        package_env,
        "pacman",
        """case "$*" in
    '-Q chaotic-keyring chaotic-mirrorlist') test -f "$HOME/trust-installed" ;;
    *) exit 97 ;;
esac""",
    )
    stub(
        package_env,
        "pacman-conf",
        'echo core; if test -f "$HOME/repo-enabled"; then echo chaotic-aur; fi',
    )
    stub(
        package_env,
        "sudo",
        """test -d "$GNUPGHOME" || exit 98
case "$*" in
    'pacman-key --list-keys 3056513887B78AEB') exit 1 ;;
    'pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com'|'pacman-key --lsign-key 3056513887B78AEB') exit 0 ;;
    'pacman -U --needed --noconfirm '*) touch "$HOME/trust-installed" ;;
    'tee -a /etc/pacman.conf') cat >> "$HOME/pacman.conf"; touch "$HOME/repo-enabled" ;;
    'pacman -Syu --noconfirm')
        test -f "$HOME/trust-installed" && test -f "$HOME/repo-enabled" || exit 98
        exit "$UPGRADE_STATUS" ;;
    *) exit 97 ;;
esac""",
        log=True,
    )
    stub(
        package_env,
        "mise",
        r"""if [ "$*" = '--env aur-helper bootstrap packages apply --yes' ]; then
    printf '#!/bin/sh\nexit 97\n' > "$HOME/bin/yay"
    chmod 755 "$HOME/bin/yay"
elif [ "$*" != '--env packages bootstrap packages apply --yes' ]; then
    exit 97
fi""",
        log=True,
    )
    marker = tmp_path / "state/chezmoi/chaotic-aur-updated"
    package_env["UPGRADE_STATUS"] = "23"
    failed = apply_packages(package_env)
    assert failed.returncode == 23, failed.stderr
    assert "sudo pacman -Syu --noconfirm failed (exit 23)" in failed.stderr
    assert failed.stderr.count("[ERROR]") == 1
    assert "Traceback" not in failed.stderr
    assert not marker.exists()
    assert not any(call[0] == "mise" for call in calls(package_env))
    package_env["UPGRADE_STATUS"] = "0"
    for _ in range(2):
        result = apply_packages(package_env)
        assert result.returncode == 0, result.stderr
    recorded = calls(package_env)
    assert [call[1] for call in recorded[:7]] == [
        "pacman-key",
        "pacman-key",
        "pacman-key",
        "pacman",
        "tee",
        "pacman",
        "pacman",
    ]
    assert [call[2] for call in recorded if call[0] == "mise"] == [
        "aur-helper",
        "packages",
        "packages",
    ]
    assert (tmp_path / "pacman.conf").read_text().count("[chaotic-aur]") == 1
    assert marker.is_file()


@pytest.mark.parametrize(
    ("gpu", "version", "family", "module"),
    [
        (
            "NVIDIA Corporation GP106 [10de:1234]",
            "580.119.02",
            "nvidia-legacy",
            "nvidia-legacy-dkms",
        ),
        ("NVIDIA Corporation GA106 [10de:1234]", "615.78.08", "nvidia-current", "nvidia-open"),
    ],
    ids=["legacy-driver", "current-driver"],
)
def test_personal_package_groups_preserve_driver_order(
    package_env: dict[str, str], gpu: str, version: str, family: str, module: str
) -> None:
    package_env.update(GPU=gpu, DRIVER_VERSION=version)
    result = apply_packages(package_env, personal=True)
    assert result.returncode == 0, result.stderr
    recorded = [call for call in calls(package_env) if call[0] == "mise"]
    groups = recorded[-1][2].split(",")
    assert {
        "packages",
        "personal",
        "driver-utils",
        "laptop",
        "limine-mkinitcpio",
        "snapper",
        family,
        module,
    } <= set(groups)
    if family == "nvidia-legacy":
        assert recorded[0][1:3] == ["--env", "nvidia-legacy-utils"]


@pytest.mark.parametrize("distro", ["cachyos", "garuda"])
def test_derivatives_keep_distribution_managed_nvidia_modules(
    package_env: dict[str, str], distro: str
) -> None:
    package_env["GPU"] = "NVIDIA Corporation GA106 [10de:1234]"
    result = apply_packages(package_env, personal=True, distro=distro)
    assert result.returncode == 0, result.stderr
    groups = [call for call in calls(package_env) if call[0] == "mise"][-1][2].split(",")
    assert "nvidia-current" in groups
    assert "nvidia-open" not in groups


@pytest.mark.parametrize(
    "packages",
    ["linux 6.18-1\nlinux-headers 6.17-1", "nvidia-580xx-utils 580.119.02-1"],
    ids=["mismatched-headers", "conflicting-userspace"],
)
def test_driver_conflicts_stop_before_mise(
    package_env: dict[str, str], tmp_path: Path, packages: str
) -> None:
    package_env.update(GPU="NVIDIA Corporation GA106 [10de:1234]", PACKAGES=packages)
    result = apply_packages(package_env, personal=True)
    assert result.returncode != 0
    assert result.stderr.count("[ERROR]") == 1
    assert "Traceback" not in result.stderr
    persisted = (tmp_path / "state/chezmoi/logs/setup.log").read_text()
    assert persisted.count("[ERROR]") == 1
    assert "Traceback (most recent call last):" in persisted
    assert "in personal_packages" in persisted
    assert "raise ValueError(" in persisted
    assert "ValueError:" in persisted
    assert not any(call[0] == "mise" for call in calls(package_env))


def test_missing_nvidia_module_fails_after_package_installation(
    package_env: dict[str, str],
) -> None:
    package_env["GPU"] = "NVIDIA Corporation GA106 [10de:1234]"
    stub(package_env, "modinfo", "exit 23")
    result = apply_packages(package_env, personal=True)
    assert result.returncode != 0
    assert "6.18-fixture" in result.stderr
    assert any(call[0] == "mise" for call in calls(package_env))


def test_xdg_reapplication_preserves_custom_paths_and_maven_settings(
    package_env: dict[str, str], tmp_path: Path
) -> None:
    package_env.update(
        GNUPGHOME=str(tmp_path / "private-gnupg"), CARGO_HOME=str(tmp_path / "custom-cargo")
    )
    settings = tmp_path / "config/maven/settings.xml"
    settings.parent.mkdir(parents=True)
    settings.write_text("existing-private-settings")
    before = settings.stat().st_mtime_ns
    for _ in range(2):
        result = apply_packages(package_env)
        assert result.returncode == 0, result.stderr
        assert settings.read_text() == "existing-private-settings"
        assert settings.stat().st_mtime_ns == before
        assert "existing-private-settings" not in result.stderr
    observed = cast("dict[str, str]", json.loads((tmp_path / "observed.json").read_text()))
    assert observed["CARGO_HOME"] == package_env["CARGO_HOME"]
    assert observed["GNUPGHOME"] == package_env["GNUPGHOME"]
    assert Path(package_env["GNUPGHOME"]).stat().st_mode & 0o777 == 0o700
    assert calls(package_env).count(["sudo", "pacman", "-Syu", "--noconfirm"]) == 1
    # A mistaken custom GnuPG path must preserve the file and explain the Python failure.
    package_env["GNUPGHOME"] = str(settings)
    recorded = calls(package_env)
    failed = apply_packages(package_env)
    assert failed.returncode == 1, failed.stderr
    assert "File exists" in failed.stderr
    assert "Traceback" not in failed.stderr
    persisted = (tmp_path / "state/chezmoi/logs/setup.log").read_text()
    assert "FileExistsError:" in persisted
    assert "in prepare_xdg" in persisted
    assert "existing-private-settings" not in persisted + failed.stderr
    assert settings.read_text() == "existing-private-settings"
    assert calls(package_env) == recorded


def test_chezmoi_retries_failures_and_tracks_only_package_dependencies(
    package_env: dict[str, str], tmp_path: Path
) -> None:
    assert CHEZMOI is not None, "chezmoi is required for package change detection"
    repository = tmp_path / "source"
    templates = repository / "home/.chezmoitemplates"
    scripts = repository / "home/.chezmoiscripts/linux"
    templates.mkdir(parents=True)
    scripts.mkdir(parents=True)
    shutil.copytree(ROOT / "mise", repository / "mise")
    shutil.copytree(ROOT / "home/.chezmoitemplates/lib", templates / "lib")
    launcher = PACKAGES
    shutil.copy(SCRIPTS / launcher, scripts / launcher)
    config = tmp_path / "chezmoi.json"
    config.write_text(
        json.dumps(
            {
                "data": {"personal": False, "distroFamily": "arch"},
                "scriptEnv": {"DOTFILES_PERSONAL_ENABLED": "0"},
            }
        )
    )
    command = [
        CHEZMOI,
        "--config",
        str(config),
        "--source",
        str(repository / "home"),
        "--working-tree",
        str(repository),
        "--destination",
        str(tmp_path / "target"),
        "--no-tty",
        "apply",
    ]
    package_env["MISE_STATUS"] = "23"
    failed = run_setup(package_env, command)
    assert failed.returncode != 0
    package_env["MISE_STATUS"] = "0"
    # A stateful apply sequence: retry, no-op, unrelated changes, then package inputs.
    for target, expected in (
        (None, 2),
        (None, 2),
        (repository / "mise/conf.d/services.toml", 2),
        (repository / "mise/conf.d/packages.toml", 3),
        (templates / "lib/provision_logging.py", 3),
        (scripts / launcher, 4),
    ):
        if target:
            with target.open("a") as stream:
                stream.write("\n# changed\n")
        result = run_setup(package_env, command)
        assert result.returncode == 0, result.stderr
        assert sum(call[0] == "mise" for call in calls(package_env)) == expected, target


@pytest.mark.parametrize("personal", [False, True], ids=["nonpersonal", "personal"])
def test_direct_python_execution_follows_bootstrap_and_real_source_imports(
    env: dict[str, str], tmp_path: Path, bootstrap: list[str], personal: bool
) -> None:
    assert CHEZMOI is not None
    repository = tmp_path / 'checkout "quoted" \\ path\nUnicode 雪😀'
    source = repository / "home"
    scripts = source / ".chezmoiscripts/linux"
    scripts.mkdir(parents=True)
    (repository / ".chezmoiroot").write_text("home\n")
    shutil.copy(ROOT / "home/.chezmoi.yaml.tmpl", source / ".chezmoi.yaml.tmpl")
    shutil.copytree(LOGGING.parent, source / ".chezmoitemplates/lib")
    for name in ("run_before_00-install-pre-requisites.sh", AUTHENTICATION):
        shutil.copy(SCRIPTS / name, scripts / name)
    # Observe only execution context; the authentication workflow itself remains
    # intact. Poison PATH Python so the configured interpreter is essential.
    probe = scripts / "run_before_00_execution_probe.py.tmpl"
    probe.write_text("""#!/usr/bin/python3 -B
# source-dir: {{ .chezmoi.sourceDir | toJson }}
import json, os, sys
from pathlib import Path
source = Path(os.environ["CHEZMOI_SOURCE_DIR"])
sys.path.insert(0, str(source / ".chezmoitemplates"))
from lib.provision_logging import configure_logging
assert (Path.home() / "installed").exists()
with (Path.home() / "execution.jsonl").open("a") as stream:
    stream.write(json.dumps({"file": __file__, "cwd": str(Path.cwd()), "source": str(source), "working_tree": os.environ["CHEZMOI_WORKING_TREE"], "distro": os.environ["CHEZMOI_OS_RELEASE_ID"], "interpreter": sys.executable, "bytecode": sys.dont_write_bytecode, "logging": configure_logging.__module__}) + "\\n")
""")
    stub(env, "python3", "exit 97", log=True)
    stub(env, "pacman", '[ "$1" = -Q ] && test -f "$HOME/installed"')
    stub(
        env,
        "sudo",
        '[ "${INSTALL_STATUS:-0}" = 0 ] || exit "$INSTALL_STATUS"; touch "$HOME/installed"',
        log=True,
    )
    command = [
        CHEZMOI,
        "--config",
        str(tmp_path / "chezmoi.yaml"),
        "--source",
        str(repository),
        "--working-tree",
        str(repository),
        "--destination",
        str(tmp_path),
        "--no-tty",
        "--override-data",
        '{"chezmoi":{"osRelease":{"id":"arch"}}}',
    ]
    result = run_setup(
        env, command + ["init", "--promptBool", f"Is this a personal setup={str(personal).lower()}"]
    )
    assert result.returncode == 0, result.stderr
    env["INSTALL_STATUS"] = "23"
    failed = run_setup(env, command + ["apply"])
    assert failed.returncode != 0
    assert not (tmp_path / "execution.jsonl").exists()
    assert not any(call[0] == "rbw" for call in calls(env))
    env["INSTALL_STATUS"] = "0"
    for _ in range(2):
        result = run_setup(env, command + ["apply"])
        assert result.returncode == 0, result.stderr
    contexts = [
        cast("dict[str, object]", json.loads(line))
        for line in (tmp_path / "execution.jsonl").read_text().splitlines()
    ]
    assert len(contexts) == 2
    for context in contexts:
        assert context["source"] == str(source)
        assert context["working_tree"] == str(repository)
        assert context["distro"] == "arch"
        assert context["cwd"] == str(tmp_path)
        assert context["interpreter"] == PYTHON
        assert context["bytecode"] is True
        assert context["logging"] == "lib.provision_logging"
        executable = Path(str(context["file"]))
        assert executable.parent != scripts and not executable.exists()
    observed = calls(env)
    assert not any(call[0] == "python3" for call in observed)
    assert sum(call[0] == "rbw" and call[1] == "login" for call in observed) == (
        2 if personal else 0
    )
    assert sum(call[0] == "sudo" for call in observed) == 2
    assert bootstrap  # Reuse the established private prerequisite/vault fixture.


def test_lock_timeout_failure_stops_before_vault_login(
    env: dict[str, str], authentication: list[str]
) -> None:
    env.update(RBW_CONFIG=json.dumps({"email": "fixture@example.invalid"}), RBW_LOCK_STATUS="23")
    result = run_setup(env, authentication)
    assert result.returncode == 23, result.stderr
    assert calls(env) == [
        ["rbw", "config", "show"],
        ["rbw", "config", "set", "lock_timeout", "10800"],
    ]
    assert "fixture@example.invalid" not in result.stderr
