"""Snapper orchestration and root-fstab safety without privileged host operations."""

import json
import shutil
import subprocess
import sys
from pathlib import Path
from typing import cast

import pytest
import snapshots
from helpers import CHEZMOI, ROOT, SCRIPTS
from test_setup import calls, run_setup, stub
from test_setup import env as env


@pytest.fixture
def snapper(env: dict[str, str], tmp_path: Path) -> dict[str, str]:
    for name in ("mkdir",):
        executable = shutil.which(name)
        assert executable is not None
        (Path(env["PATH"]) / name).symlink_to(executable)
    limine = tmp_path / "limine"
    limine.touch(mode=0o755)
    # Copy the actual module/launcher and replace only the unavailable fixed
    # bootloader binary in the isolated fixture, never live filesystem paths.
    source = tmp_path / "source"
    scripts = source / ".chezmoiscripts/linux"
    scripts.mkdir(parents=True)
    shutil.copy(SCRIPTS / "run_onchange_after_01_snapper.sh.tmpl", scripts)
    templates = source / ".chezmoitemplates"
    shutil.copytree(ROOT / "home/.chezmoitemplates", templates)
    module = templates / "snapshots.py"
    module.write_text(
        module.read_text().replace('Path("/usr/bin/limine")', f"Path({str(limine)!r})")
    )
    stub(env, "mkinitcpio", "exit 97")
    stub(env, "rbw", "exit 97", log=True)
    stub(
        env,
        "btrfs",
        '[ "$1 $2" = "subvolume show" ] || exit 97; [ "$3" != /.snapshots ] || exit "${BTRFS_STATUS:-0}"; exit 0',
    )
    stub(
        env,
        "bash",
        """case "$1" in
    */snapper_boot.sh) printf 'boot\\t%s\\t\\n' "$2" >> "$CALLS"; exit 0 ;;
    *) exec /bin/bash "$@" ;;
esac""",
    )
    stub(
        env,
        "findmnt",
        '''printf '{"filesystems":[{"target":"/","fstype":"%s","fsroot":"%s","uuid":"00000000-0000-0000-0000-000000000001","options":"rw,relatime"}]}\\n' "${ROOT_FS:-btrfs}" "${ROOT_SUBVOL:-/@}"''',
        log=True,
    )
    stub(
        env,
        "sudo",
        """case "$1" in
    test)
        [ "$3" = /.snapshots ] || exit 97
        exec /usr/bin/test "$2" "$HOME/snapshots" ;;
    snapper|btrfs|systemctl) exec "$@" ;;
    */python|*/python3)
        case "$*" in *--optimize-fstab) exit "${FSTAB_STATUS:-0}" ;; *) exit 97 ;; esac ;;
    *) exit 97 ;;
esac""",
        log=True,
    )
    stub(
        env,
        "snapper",
        """exec /usr/bin/python3 - "$@" <<'SCRIPT'
import os, sys
from pathlib import Path
args = sys.argv[1:]
home = Path.home()
config = home / 'snapper.json'
command = next(part for part in args if part in ('list-configs', 'get-config', 'create-config', 'set-config'))
if command == os.environ.get('FAIL_COMMAND'):
    print('fixture Snapper failure', file=sys.stderr)
    sys.exit(23)
settings = __import__('json').loads(config.read_text()) if config.exists() else None
if command == 'list-configs':
    if settings is not None: print('root,' + os.environ.get('ROOT_CONFIG_PATH', '/'))
elif command == 'get-config':
    for key, value in settings.items(): print(key + ',' + value)
elif command == 'create-config':
    (home / 'snapshots').mkdir()
    settings = {'SUBVOLUME': '/', 'FSTYPE': 'btrfs', 'NUMBER_LIMIT': '50', 'UNMANAGED': 'preserve'}
else:
    for item in args[args.index('set-config') + 1:]:
        key, value = item.split('=', 1)
        settings[key] = value
if command in ('create-config', 'set-config'):
    config.write_text(__import__('json').dumps(settings))
SCRIPT""",
    )
    stub(
        env,
        "systemctl",
        """case "$1" in
    is-enabled)
        if test -f "$HOME/$2"; then echo enabled; else echo disabled; exit 1; fi ;;
    enable)
        [ "${FAIL_COMMAND:-}" != enable ] || exit 23
        touch "$HOME/$2" ;;
    *) exit 97 ;;
esac""",
    )
    return env


def apply_command(tmp_path: Path, *, personal: bool = True) -> list[str]:
    assert CHEZMOI is not None
    config = tmp_path / "chezmoi.json"
    config.write_text(json.dumps({"data": {"personal": personal}}))
    return [
        CHEZMOI,
        "--config",
        str(config),
        "--source",
        str(tmp_path / "source"),
        "--destination",
        str(tmp_path),
        "--no-tty",
        "--override-data",
        '{"chezmoi":{"osRelease":{"id":"arch"}}}',
        "apply",
    ]


def mutations(env: dict[str, str]) -> list[list[str]]:
    return [
        call
        for call in calls(env)
        if call[0] == "boot"
        or any(
            part in ("create-config", "set-config", "enable", "--optimize-fstab") for part in call
        )
    ]


@pytest.mark.parametrize("existing", [False, True], ids=["fresh", "configured"])
def test_snapper_apply_and_state_based_reapplication(
    snapper: dict[str, str], tmp_path: Path, existing: bool
) -> None:
    if existing:
        settings = {
            "SUBVOLUME": "/",
            "FSTYPE": "btrfs",
            "UNMANAGED": "preserve",
            **snapshots.SETTINGS,
        }
        (tmp_path / "snapper.json").write_text(json.dumps(settings))
        (tmp_path / "snapshots/42/snapshot").mkdir(parents=True)
        (tmp_path / "snapshots/42/snapshot/sentinel").write_text("existing snapshot")
    command = apply_command(tmp_path)
    result = run_setup(snapper, command)
    assert result.returncode == 0, result.stderr
    settings = cast("dict[str, str]", json.loads((tmp_path / "snapper.json").read_text()))
    assert settings.items() >= snapshots.SETTINGS.items()
    assert settings["UNMANAGED"] == "preserve"
    observed = calls(snapper)
    assert [call for call in observed if call[0] == "boot"] == [
        ["boot", "prepare"],
        ["boot", "overlay"],
    ]
    assert not any(
        call[0] == "rbw" or "delete" in call or "start" in call or "restart" in call
        for call in observed
    )
    if existing:
        assert (tmp_path / "snapshots/42/snapshot/sentinel").read_text() == "existing snapshot"
        assert not any("create-config" in call or "set-config" in call for call in observed)
    else:
        create = next(call for call in observed if "create-config" in call)
        assert (
            observed.index(["boot", "prepare"])
            < observed.index(create)
            < observed.index(["boot", "overlay"])
        )
    result = run_setup(snapper, command)
    assert result.returncode == 0, result.stderr
    assert calls(snapper) == observed
    # Force the real trigger to run again: native state must avoid configuration
    # creation, unchanged settings and repeated unit activation independently.
    module = tmp_path / "source/.chezmoitemplates/snapshots.py"
    module.write_text(module.read_text() + "\n# Recheck actual configured state.\n")
    result = run_setup(snapper, command)
    assert result.returncode == 0, result.stderr
    subsequent = calls(snapper)[len(observed) :]
    assert not any(
        "create-config" in call or "set-config" in call or "enable" in call for call in subsequent
    )
    assert result.stderr == ""


def test_nonpersonal_apply_never_enters_filesystem_provisioning(
    snapper: dict[str, str], tmp_path: Path
) -> None:
    result = run_setup(snapper, apply_command(tmp_path, personal=False))
    assert result.returncode == 0, result.stderr
    assert calls(snapper) == []


@pytest.mark.parametrize(
    "scenario",
    [
        "non-btrfs",
        "wrong-subvolume",
        "orphan-snapshots",
        "conflicting-config",
        "ordinary-directory",
    ],
)
def test_unexpected_filesystem_state_is_preserved(
    snapper: dict[str, str], tmp_path: Path, scenario: str
) -> None:
    if scenario == "non-btrfs":
        snapper["ROOT_FS"] = "ext4"
    elif scenario == "wrong-subvolume":
        snapper["ROOT_SUBVOL"] = "/unexpected"
    else:
        (tmp_path / "snapshots").mkdir()
        (tmp_path / "snapshots/sentinel").write_text("preserve")
        if scenario != "orphan-snapshots":
            (tmp_path / "snapper.json").write_text(
                json.dumps({"SUBVOLUME": "/", "FSTYPE": "btrfs"})
            )
        if scenario == "conflicting-config":
            snapper["ROOT_CONFIG_PATH"] = "/home"
        elif scenario == "ordinary-directory":
            snapper["BTRFS_STATUS"] = "23"
    result = run_setup(snapper, apply_command(tmp_path))
    assert (result.returncode == 0) == (scenario == "non-btrfs"), result.stderr
    assert mutations(snapper) == []
    if (tmp_path / "snapshots/sentinel").exists():
        assert (tmp_path / "snapshots/sentinel").read_text() == "preserve"


@pytest.mark.parametrize("failure", ["list-configs", "create-config", "set-config", "enable"])
def test_failure_status_and_retry_preserve_completed_work(
    snapper: dict[str, str], tmp_path: Path, failure: str
) -> None:
    snapper["FAIL_COMMAND"] = failure
    command = [
        sys.executable,
        "-B",
        str(tmp_path / "source/.chezmoitemplates/snapshots.py"),
        "--personal",
        "--distro",
        "arch",
    ]
    result = run_setup(snapper, command)
    assert result.returncode == 23, result.stderr
    assert "exit 23" in result.stderr
    if failure == "list-configs":
        assert mutations(snapper) == []
    del snapper["FAIL_COMMAND"]
    result = run_setup(snapper, apply_command(tmp_path))
    assert result.returncode == 0, result.stderr
    assert sum("create-config" in call for call in calls(snapper)) == (
        2 if failure == "create-config" else 1
    )


FSTAB = "# preserve comments\nUUID=root / btrfs rw,relatime,subvol=/@ 0 0 # root\nUUID=root /swap btrfs relatime,subvol=/@swap 0 0\nUUID=other /mnt/data btrfs relatime 0 0\n/swap/swapfile none swap defaults 0 0\n"


def test_root_fstab_is_atomic_idempotent_and_leaves_swap_alone(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    path = tmp_path / "fstab"
    path.write_text(FSTAB)
    path.chmod(0o640)
    commands: list[list[str]] = []

    def reload(command: list[str], *, check: bool) -> subprocess.CompletedProcess[str]:
        assert check
        commands.append(command)
        return subprocess.CompletedProcess(command, 0)

    monkeypatch.setattr(subprocess, "run", reload)
    assert snapshots.optimize_fstab(path)
    assert path.read_text() == FSTAB.replace("rw,relatime,subvol=/@ ", "rw,noatime,subvol=/@ ")
    assert path.stat().st_mode & 0o777 == 0o640
    before = path.stat().st_mtime_ns
    assert not snapshots.optimize_fstab(path)
    assert path.stat().st_mtime_ns == before
    assert commands == [["systemctl", "daemon-reload"]]


@pytest.mark.parametrize(
    "concurrent_edit", [False, True], ids=["rollback", "preserve-intervening-edit"]
)
def test_failed_reload_restores_only_its_own_fstab_edit(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, concurrent_edit: bool
) -> None:
    path = tmp_path / "fstab"
    path.write_text(FSTAB)

    def fail(command: list[str], *, check: bool) -> subprocess.CompletedProcess[str]:
        assert check
        if concurrent_edit:
            path.write_text("manual edit\n")
        raise subprocess.CalledProcessError(23, command)

    monkeypatch.setattr(subprocess, "run", fail)
    with pytest.raises(subprocess.CalledProcessError) as error:
        snapshots.optimize_fstab(path)
    assert error.value.returncode == 23
    assert path.read_text() == ("manual edit\n" if concurrent_edit else FSTAB)
    assert not list(tmp_path.glob(".fstab.chezmoi.*"))


def test_symlinked_fstab_is_refused(tmp_path: Path) -> None:
    target = tmp_path / "original"
    target.write_text(FSTAB)
    path = tmp_path / "fstab"
    path.symlink_to(target)
    with pytest.raises(OSError):
        snapshots.optimize_fstab(path)
    assert target.read_text() == FSTAB


def test_interrupted_reload_restores_fstab(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    path = tmp_path / "fstab"
    path.write_text(FSTAB)

    def interrupt(command: list[str], *, check: bool) -> subprocess.CompletedProcess[str]:
        assert command == ["systemctl", "daemon-reload"] and check
        raise SystemExit(143)

    monkeypatch.setattr(subprocess, "run", interrupt)
    with pytest.raises(SystemExit) as error:
        snapshots.optimize_fstab(path)
    assert error.value.code == 143
    assert path.read_text() == FSTAB
