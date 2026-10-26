"""Personal laptop power setup delegates installation and daemon changes to upstream."""

import json
import shutil
from pathlib import Path

import pytest
from helpers import CHEZMOI, ROOT, SCRIPTS
from test_setup import PYTHON, calls, render_python, run_setup, stub
from test_setup import env as env

HOOK = "run_onchange_after_02_laptop_power.py"


@pytest.fixture
def laptop_env(env: dict[str, str], tmp_path: Path) -> dict[str, str]:
    # Redirect the fixed upstream installation path into the private test home.
    source = tmp_path / "source"
    scripts = source / ".chezmoiscripts/linux"
    scripts.mkdir(parents=True)
    shutil.copytree(ROOT / "home/.chezmoitemplates/lib", source / ".chezmoitemplates/lib")
    script = (
        (SCRIPTS / HOOK)
        .read_text()
        .replace('Path("/usr/local/bin/auto-cpufreq")', f"Path({str(tmp_path / 'auto-cpufreq')!r})")
    )
    (scripts / HOOK).write_text(script)
    env["CHEZMOI_SOURCE_DIR"] = str(source)
    env["DOTFILES_PERSONAL_ENABLED"] = "1"
    stub(
        env,
        "hostnamectl",
        'printf "%s\\n" "${CHASSIS:-laptop}"; exit "${CHASSIS_STATUS:-0}"',
        log=True,
    )
    stub(
        env,
        "curl",
        'printf \'{"tag_name":"v3.2.0"}\\n\'; exit "${CURL_STATUS:-0}"',
        log=True,
    )
    stub(
        env,
        "git",
        '''[ "${GIT_STATUS:-0}" = 0 ] || exit "$GIT_STATUS"
/usr/bin/mkdir -p "$7"
/usr/bin/cp "$HOME/installer" "$7/auto-cpufreq-installer"''',
        log=True,
    )
    stub(env, "sudo", 'exec "$@"', log=True)
    stub(env, "rm", 'exec /usr/bin/rm "$@"')
    stub(
        env,
        "systemctl",
        """[ "$*" = "is-active --quiet auto-cpufreq.service" ] || exit 97
[ "${INSPECTION_STATUS:-0}" = 0 ] || exit "$INSPECTION_STATUS"
[ -f "$HOME/active" ] && exit 0
exit 3""",
        log=True,
    )
    (tmp_path / "installer").write_text(
        """[ "$1" = --install ] || exit 97
echo "Native source installer output"
if [ "${INSTALL_PROMPT:-0}" = 1 ]; then
  printf "Installer confirmation: "; read -r answer; [ "$answer" = yes ] || exit 98
fi
[ "${INSTALL_STATUS:-0}" = 0 ] || exit "$INSTALL_STATUS"
/usr/bin/cp "$HOME/daemon" "$HOME/auto-cpufreq"
"""
    )
    daemon = tmp_path / "daemon"
    daemon.write_text(
        """#!/bin/sh
[ "$1" = --install ] || exit 97
echo "Native daemon installer output"
[ "${DAEMON_STATUS:-0}" = 0 ] || exit "$DAEMON_STATUS"
touch "$HOME/active"
"""
    )
    daemon.chmod(0o755)
    return env


@pytest.mark.parametrize("personal,chassis", [(False, "laptop"), (True, "desktop")])
def test_inapplicable_profiles_and_hardware_skip_before_installation(
    laptop_env: dict[str, str], personal: bool, chassis: str
) -> None:
    laptop_env["CHASSIS"] = chassis
    script = render_python(
        laptop_env, HOOK, personal=personal, source=Path(laptop_env["CHEZMOI_SOURCE_DIR"])
    )
    result = run_setup(laptop_env, [PYTHON, "-B", str(script)])
    assert result.returncode == 0, result.stderr
    assert result.stdout == result.stderr == ""
    assert calls(laptop_env) == ([["hostnamectl", "chassis"]] if personal else [])


def test_upstream_installers_keep_native_input_and_output(
    laptop_env: dict[str, str], tmp_path: Path
) -> None:
    laptop_env["INSTALL_PROMPT"] = "1"
    script = render_python(laptop_env, HOOK, source=Path(laptop_env["CHEZMOI_SOURCE_DIR"]))
    result = run_setup(laptop_env, [PYTHON, "-B", str(script)], input="yes\n")
    assert result.returncode == 0, result.stderr
    assert "Installer confirmation:" in result.stdout
    assert "Native daemon installer output" in result.stdout
    assert (tmp_path / "active").exists()


@pytest.mark.parametrize(
    "failure,status",
    [("CHASSIS_STATUS", 23), ("CURL_STATUS", 22), ("GIT_STATUS", 24), ("INSPECTION_STATUS", 1)],
)
def test_inspection_and_download_errors_preserve_status(
    laptop_env: dict[str, str], tmp_path: Path, failure: str, status: int
) -> None:
    laptop_env[failure] = str(status)
    script = render_python(laptop_env, HOOK, source=Path(laptop_env["CHEZMOI_SOURCE_DIR"]))
    result = run_setup(laptop_env, [PYTHON, "-B", str(script)])
    assert result.returncode == status, result.stderr
    assert f"Laptop power setup failed (exit {status})" in result.stderr
    assert "Traceback" not in result.stderr
    assert "CalledProcessError" in (tmp_path / "state/chezmoi/logs/setup.log").read_text()
    assert not (tmp_path / "active").exists()
    assert not list(tmp_path.glob("chezmoi-auto-cpufreq-*"))


@pytest.mark.parametrize("failure", ["INSTALL_STATUS", "DAEMON_STATUS"])
def test_native_chezmoi_retries_installer_failure_then_caches_success(
    laptop_env: dict[str, str], tmp_path: Path, failure: str
) -> None:
    assert CHEZMOI is not None
    source = Path(laptop_env["CHEZMOI_SOURCE_DIR"])
    scripts = source / ".chezmoiscripts/linux"
    # Boundaries prove the laptop hook keeps its established after-script order.
    for order in ("01", "03"):
        (scripts / f"run_onchange_after_{order}_probe.sh").write_text(
            f'#!/bin/sh\necho {order} >> "$HOME/order"\n'
        )
    config = tmp_path / "chezmoi.json"
    config.write_text(json.dumps({"scriptEnv": {"DOTFILES_PERSONAL_ENABLED": "1"}}))
    command = [
        CHEZMOI,
        "--config",
        str(config),
        "--source",
        str(source),
        "--destination",
        str(tmp_path / "target"),
        "--no-tty",
        "apply",
    ]
    laptop_env[failure] = "42"
    failed = run_setup(laptop_env, command)
    assert failed.returncode != 0
    assert "exit 42" in failed.stderr
    assert (tmp_path / "order").read_text() == "01\n"
    assert not (tmp_path / "active").exists()
    assert not list(tmp_path.glob("chezmoi-auto-cpufreq-*"))
    if failure == "DAEMON_STATUS":
        assert (tmp_path / "auto-cpufreq").is_file()
    laptop_env[failure] = "0"
    retried = run_setup(laptop_env, command)
    assert retried.returncode == 0, retried.stderr
    assert "Native daemon installer output" in retried.stdout
    assert (tmp_path / "order").read_text() == "01\n03\n"
    assert (tmp_path / "active").exists()
    observed = calls(laptop_env)
    cached = run_setup(laptop_env, command)
    assert cached.returncode == 0, cached.stderr
    assert calls(laptop_env) == observed
    # A deliberate hook change may re-execute it; an active daemon stays untouched.
    with (scripts / HOOK).open("a") as stream:
        stream.write("\n# changed\n")
    reapplied = run_setup(laptop_env, command)
    assert reapplied.returncode == 0, reapplied.stderr
    assert calls(laptop_env)[len(observed) :] == [
        ["hostnamectl", "chassis"],
        ["systemctl", "is-active", "--quiet", "auto-cpufreq.service"],
    ]
    cloned = [call for call in observed if call[0] == "git"]
    assert len(cloned) == (2 if failure == "INSTALL_STATUS" else 1)
    for call in cloned:
        assert call[1:-1] == [
            "clone",
            "--single-branch",
            "--branch",
            "v3.2.0",
            "--",
            "https://github.com/AdnanHodzic/auto-cpufreq.git",
        ]
    for call in observed:
        if call[0] == "systemctl":
            assert call == ["systemctl", "is-active", "--quiet", "auto-cpufreq.service"]
        if call[:2] == ["sudo", "bash"]:
            assert call[-1] == "--install"
        if call[0] == "sudo" and call[1] == str(tmp_path / "auto-cpufreq"):
            assert call[-1] == "--install"
    assert not list(tmp_path.glob("chezmoi-auto-cpufreq-*"))
    assert "auto-cpufreq" not in (ROOT / "mise/conf.d/packages.toml").read_text()
    assert "auto-cpufreq" not in (ROOT / "mise/conf.d/services.toml").read_text()
