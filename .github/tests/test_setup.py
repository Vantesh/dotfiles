"""Fresh profiles and bootstrap behavior, with system operations confined to a private home."""

import json
import os
import pty
import re
import runpy
import shlex
import shutil
import subprocess
from pathlib import Path
from typing import cast

import pytest
from helpers import CHEZMOI, ROOT, SCRIPTS
from loguru import logger

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


def bootstrap_packages() -> tuple[list[str], list[str]]:
    text = (SCRIPTS / "run_before_00-install-pre-requisites.sh").read_text()
    base = re.search(r"^\s*packages=\((.*)\)\s*$", text, re.MULTILINE)
    personal = re.search(r"^\s*packages\+=\((.*)\)\s*$", text, re.MULTILINE)
    if base is None or personal is None:
        raise AssertionError("Bootstrap package declarations were not found")
    return base[1].split(), personal[1].split()


@pytest.fixture(scope="module")
def lock_timeout() -> int:
    value = runpy.run_path(str(SCRIPTS / AUTHENTICATION))["LOCK_TIMEOUT"]
    if not isinstance(value, int):
        raise AssertionError("LOCK_TIMEOUT must be an integer")
    return value


@pytest.mark.parametrize(
    "hook",
    [AUTHENTICATION],
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
    result = run_setup(env, [PYTHON, "-B", str(script)])
    assert result.returncode == (0 if profile == "0" else 1)
    assert result.stdout == ""
    if profile == "0":
        assert result.stderr == ""
    else:
        assert "DOTFILES_PERSONAL_ENABLED must be '0' or '1'" in result.stderr
    assert not calls(env)
    assert not (tmp_path / "state").exists()


def test_nonpersonal_apply_is_isolated(env: dict[str, str], tmp_path: Path) -> None:
    assert CHEZMOI is not None, "chezmoi is required for profile validation"
    env.update(NOCONFIRM="1", OFFLINE="1", CHEZMOI_SOURCE_DIR=str(ROOT / "home"))
    stub(env, "chezmoi", f'exec {shlex.quote(CHEZMOI)} "$@"')
    stub(env, "id", "echo 1000")
    stub(env, "paru", "exit 97")
    stub(env, "pacman", '[ "$1" = --query ] || exit 127')
    stub(env, "pacman-conf", '[ "$*" = --repo-list ] || exit 97; echo chaotic-aur')
    stub(
        env,
        "sudo",
        """case "$*" in
    --validate|'--non-interactive true'|'pacman --sync --refresh --sysupgrade --noconfirm') exit 0 ;;
esac
# Desktop theming mirrors root GTK for every profile.
[ "$#" -ge 5 ] && [ "$1" = --non-interactive ] && [ "$5" = --mirror-gtk ] && exit 0
# The common greeter's privileged work is exercised in its isolated tests.
[ "$#" = 8 ] && [ "$1" = --non-interactive ] && [ "$2" = /usr/bin/python3 ] && [ "$3" = -B ] && [ "$5" = --configure ] && [ "$7" = 0 ] || exit 97
case "$4" in
    "$TMPDIR/"*.11_login_manager.py) echo configured >> "$HOME/common-greeter" ;;
    *) exit 97 ;;
esac""",
        log=True,
    )
    stub(
        env,
        "mise",
        """case "$*" in
'--env packages bootstrap packages status --json')
    echo '{"pacman":{"available":true,"packages":[{"state":"missing"}]}}' ;;
'--env packages bootstrap packages apply --yes --quiet'|'--quiet --env  bootstrap --only services,user,files --yes') exit 0 ;;
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
        """case "$1" in
    get)
        case "$3" in
            font-name) echo "'SF Pro Text 12'" ;;
            button-layout) echo "':'" ;;
            gtk-theme) echo "'Adwaita'" ;;
            color-scheme) echo "'default'" ;;
            cursor-theme) echo "'old'" ;;
            cursor-size) echo 24 ;;
            default-zoom-level) echo "'small-plus'" ;;
            show-delete-permanently) echo true ;;
            *) exit 97 ;;
        esac ;;
    set) exit 0 ;;
    *) exit 97 ;;
esac""",
        log=True,
    )
    stub(
        env,
        "warp-cli",
        """case "$*" in
    '--accept-tos registration show')
        [ -f "$HOME/registered" ] && exit 0
        echo 'Missing registration.' >&2; exit 1 ;;
    '--accept-tos registration new') touch "$HOME/registered" ;;
    *) exit 97 ;;
esac""",
        log=True,
    )
    stub(env, "systemctl", '[ "$*" = "is-active --quiet warp-svc.service" ] || exit 97', log=True)
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
    assert "CHEZMOI_GITHUB_ACCESS_TOKEN" not in (secrets.read_text() if secrets.exists() else "")
    verified = run_setup(env, command + ["verify", "--exclude=scripts"])
    assert verified.returncode == 0, verified.stderr
    observed = calls(env)
    assert [call for call in observed if call[0] == "mise"] == [
        ["mise", "--env", "packages", "bootstrap", "packages", "status", "--json"],
        ["mise", "--env", "packages", "bootstrap", "packages", "apply", "--yes", "--quiet"],
        ["mise", "--quiet", "--env", "", "bootstrap", "--only", "services,user,files", "--yes"],
    ]
    assert [call[1:] for call in observed if call[0] == "warp-cli"] == [
        ["--accept-tos", "registration", "show"],
        ["--accept-tos", "registration", "new"],
        ["--accept-tos", "registration", "show"],
    ]
    assert any("--mirror-gtk" in call for call in observed)
    assert (tmp_path / "registered").exists()
    assert (tmp_path / "common-greeter").read_text() == "configured\n"
    assert all(
        call[0] in ("sudo", "mise", "gsettings", "warp-cli", "systemctl") for call in observed
    ), observed


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
def bootstrap(env: dict[str, str], tmp_path: Path, lock_timeout: int) -> list[str]:
    env.update(
        CHEZMOI_SOURCE_DIR=str(ROOT / "home"),
        DOTFILES_PERSONAL_ENABLED="1",
        RBW_CONFIG=json.dumps({"email": "fixture@example.invalid", "lock_timeout": lock_timeout}),
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
    'config set lock_timeout """
        + str(lock_timeout)
        + """') exit "${RBW_LOCK_STATUS:-0}" ;;
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


@pytest.mark.parametrize("personal", [False, True], ids=["nonpersonal", "personal"])
def test_prerequisites_install_in_one_transaction_and_reapply_quietly(
    env: dict[str, str], bootstrap: list[str], tmp_path: Path, personal: bool
) -> None:
    env.update(
        DOTFILES_PERSONAL_ENABLED="1" if personal else "0", INSTALLED=str(tmp_path / "installed")
    )
    packages, personal_packages = bootstrap_packages()
    expected_packages = packages + (personal_packages if personal else [])
    stub(env, "pacman", '[ "$1" = --query ] && test -f "$INSTALLED"')
    install = ["pacman", "--sync", "--needed", "--noconfirm", "--", *expected_packages]
    stub(
        env,
        "sudo",
        f'[ "$*" = {shlex.quote(" ".join(install))} ] || exit 97\ntouch "$INSTALLED"',
        log=True,
    )
    first = run_setup(env, bootstrap)
    assert first.returncode == 0, first.stderr
    assert (tmp_path / "installed").exists()
    repeated = run_setup(env, bootstrap)
    assert repeated.returncode == 0, repeated.stderr
    assert repeated.stderr == ""
    assert [call for call in calls(env) if call[0] == "sudo"] == [["sudo", *install]]
    assert not any(call[0] == "rbw" for call in calls(env))
    assert not (tmp_path / "state/chezmoi/logs/setup.log").exists()


def test_personal_authentication_preserves_existing_configuration(
    env: dict[str, str], authentication: list[str]
) -> None:
    result = run_setup(env, authentication)
    assert result.returncode == 0, result.stderr
    assert calls(env) == [["rbw", "config", "show"], ["rbw", "login"]]


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
    env: dict[str, str], authentication: list[str], tmp_path: Path, lock_timeout: int
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
        ["rbw", "config", "set", "lock_timeout", str(lock_timeout)],
        ["rbw", "login"],
    ]


def test_setup_logs_are_private_and_bounded(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    from lib import provision_logging

    # The real limits only need to be finite; shrink them so the test stays fast
    # and does not grow with the production configuration.
    assert provision_logging.LOG_ROTATION_BYTES > 0
    assert provision_logging.LOG_RETENTION > 0
    rotation, retention = 1024, 3
    monkeypatch.setattr(provision_logging, "LOG_ROTATION_BYTES", rotation)
    monkeypatch.setattr(provision_logging, "LOG_RETENTION", retention)
    monkeypatch.setenv("XDG_STATE_HOME", str(tmp_path))
    logs = tmp_path / "chezmoi/logs"
    try:
        _ = provision_logging.configure_logging()
        counts: list[int] = []
        for _batch in range(2):
            for _ in range(retention + 2):
                logger.debug("rotation-test " + "x" * rotation)
            counts.append(len(list(logs.glob("setup*.log"))))
    finally:
        logger.remove()
    # Writing well past the threshold keeps the retained set at the current file
    # plus `retention` archives instead of growing.
    assert counts == [retention + 1, retention + 1]
    assert logs.stat().st_mode & 0o777 == 0o700
    for path in logs.glob("setup*.log"):
        assert path.stat().st_mode & 0o777 == 0o600
        assert path.stat().st_uid == os.getuid()


@pytest.fixture
def package_env(env: dict[str, str]) -> dict[str, str]:
    env.update(
        NOCONFIRM="1",
        OFFLINE="1",
        PACKAGES="linux 6.18-1\nlinux-headers 6.18-1",
        GPU="Intel Corporation [8086:1234]",
        DRIVER_VERSION="615.78.08",
        MISE_STATUS="0",
        PACKAGE_STATE="missing",
        LEGACY_PACKAGE_STATE="missing",
        PACKAGE_STATUS="0",
        UPGRADE_STATUS="0",
    )
    stub(env, "id", "echo 1000")
    stub(env, "paru", "exit 97")
    stub(env, "pacman-conf", "echo chaotic-aur")
    stub(
        env,
        "pacman",
        r"""case "$*" in
    '--query chaotic-keyring chaotic-mirrorlist'|'--database --check') exit 0 ;;
    '-T vulkan-driver') exit 127 ;;
    --query) printf '%s\n' "$PACKAGES" ;;
    '--query nvidia-utils') echo "nvidia-utils $DRIVER_VERSION-1" ;;
    '--query nvidia-580xx-utils') echo "nvidia-580xx-utils $DRIVER_VERSION-1" ;;
    '--query --quiet --list linux') echo /usr/lib/modules/6.18-fixture/pkgbase ;;
    *) exit 97 ;;
esac""",
    )
    stub(
        env,
        "sudo",
        '''[ "$*" = 'pacman --sync --refresh --sysupgrade --noconfirm' ] || exit 97
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
    '--set-version 6.18-fixture --field vermagic nvidia') echo '6.18-fixture SMP' ;;
    '--set-version 6.18-fixture --field version nvidia') echo "$DRIVER_VERSION" ;;
    *) exit 97 ;;
esac""",
    )
    stub(
        env,
        "mise",
        '''if [ "$5" = status ]; then
    if [ "$2" = nvidia-legacy-utils ]; then
        state="$LEGACY_PACKAGE_STATE"
    else
        state="$PACKAGE_STATE"
    fi
    printf '{"pacman":{"available":true,"packages":[{"state":"%s"}]}}\\n' "$state"
    exit "$PACKAGE_STATUS"
fi
/usr/bin/python3 -B - <<'CHECK'
import json, os
from pathlib import Path
Path(os.environ['HOME'], 'observed.json').write_text(json.dumps({
    key: os.environ.get(key) for key in ('MISE_ENV', 'MISE_CONFIG_FILE')}))
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


def test_chaotic_trust_upgrade_and_helper_recover_then_reapply_without_duplicates(
    package_env: dict[str, str], tmp_path: Path
) -> None:
    (tmp_path / "bin/paru").unlink()
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
    'pacman --upgrade --needed --noconfirm '*) touch "$HOME/trust-installed" ;;
    'tee --append /etc/pacman.conf') cat >> "$HOME/pacman.conf"; touch "$HOME/repo-enabled" ;;
    'pacman --sync --refresh --sysupgrade --noconfirm')
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
    printf '#!/bin/sh\nexit 97\n' > "$HOME/bin/paru"
    chmod 755 "$HOME/bin/paru"
elif [ "$*" = '--env packages bootstrap packages status --json' ]; then
    echo '{"pacman":{"available":true,"packages":[{"state":"missing"}]}}'
elif [ "$*" != '--env packages bootstrap packages apply --yes --quiet' ]; then
    exit 97
fi""",
        log=True,
    )
    marker = tmp_path / "state/chezmoi/chaotic-aur-updated"
    package_env["UPGRADE_STATUS"] = "23"
    failed = apply_packages(package_env)
    assert failed.returncode == 23, failed.stderr
    assert "sudo pacman --sync --refresh --sysupgrade --noconfirm failed (exit 23)" in failed.stderr
    assert failed.stderr.count("[ERROR]") == 1
    assert "Traceback" not in failed.stderr
    assert not marker.exists()
    assert not any(call[0] == "mise" for call in calls(package_env))
    package_env["UPGRADE_STATUS"] = "0"
    for _ in range(2):
        result = apply_packages(package_env)
        assert result.returncode == 0, result.stderr
    recorded = calls(package_env)
    assert [call[2] for call in recorded if call[0] == "mise" and "apply" in call] == [
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
    recorded = [call for call in calls(package_env) if call[0] == "mise" and "apply" in call]
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
    assert "Installing baseline and personal packages with Mise." in result.stderr
    assert all(call[-1] == "--quiet" for call in recorded)
    if family == "nvidia-legacy":
        assert "Installing legacy NVIDIA utilities before driver packages." in result.stderr
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
    assert "Traceback" in persisted
    assert "ValueError:" in persisted
    assert not any(call[0] == "mise" for call in calls(package_env))


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
    stub(env, "pacman", '[ "$1" = --query ] && test -f "$HOME/installed"')
    stub(
        env,
        "sudo",
        'touch "$HOME/installed"',
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
    result = run_setup(env, command + ["apply"])
    assert result.returncode == 0, result.stderr
    contexts = [
        cast("dict[str, object]", json.loads(line))
        for line in (tmp_path / "execution.jsonl").read_text().splitlines()
    ]
    assert len(contexts) == 1
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
        1 if personal else 0
    )
    assert sum(call[0] == "sudo" for call in observed) == 1
    assert bootstrap  # Reuse the established private prerequisite/vault fixture.
