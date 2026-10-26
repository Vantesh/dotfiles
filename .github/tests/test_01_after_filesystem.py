"""Managed hibernation safety with isolated files and native-command substitutes."""

import json
import os
import shutil
import subprocess
from pathlib import Path
from typing import cast

import pytest
from helpers import CHEZMOI, ROOT, SCRIPTS
from test_setup import calls, render_python, run_setup, stub
from test_setup import env as env

HOOK = "run_onchange_after_03_hibernation.py.tmpl"
UUID = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
LUKS_UUID = "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb"


def test_hook_verification_matches_mkinitcpio_version_order(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    from lib import initramfs

    etc = tmp_path / "etc"
    dropins = etc / "mkinitcpio.conf.d"
    dropins.mkdir(parents=True)
    (etc / "mkinitcpio.conf").write_text("HOOKS=(base systemd block filesystems)\n")
    (dropins / "2-unlock.conf").write_text("HOOKS=(base systemd block sd-encrypt filesystems)\n")
    (dropins / "10-local.conf").write_text("HOOKS=(base systemd block filesystems fsck)\n")
    monkeypatch.setattr(initramfs, "ETC", etc)
    assert initramfs.read_hooks() == ["base", "systemd", "block", "filesystems", "fsck"]


@pytest.fixture
def hibernation(env: dict[str, str], tmp_path: Path) -> dict[str, str]:
    source = tmp_path / "checkout with spaces/home"
    scripts = source / ".chezmoiscripts/linux"
    scripts.mkdir(parents=True)
    shutil.copytree(ROOT / "home/.chezmoitemplates/lib", source / ".chezmoitemplates/lib")
    shutil.copytree(ROOT / "mise", source.parent / "mise")
    etc, dev, proc, sysfs = (tmp_path / name for name in ("etc", "dev", "proc", "sys"))
    for path in (
        etc / "kernel",
        etc / "default",
        etc / "limine-entry-tool.d",
        dev / "disk/by-uuid",
        dev / "disk/by-id",
        dev / "mapper",
        dev / "block",
        proc,
        sysfs,
    ):
        path.mkdir(parents=True)
    (etc / "fstab").write_text("# preserve unrelated mounts\nUUID=other /data ext4 defaults 0 0\n")
    (etc / "fstab").chmod(0o640)
    (etc / "kernel/cmdline").write_text(f"root=UUID={UUID} rootflags=subvol=@ rw quiet\n")
    (proc / "meminfo").write_text(f"MemTotal: {32 * 1024**2} kB\n")
    for name in ("fixture", "container", "other"):
        (dev / name).touch()
    (dev / "disk/by-uuid" / UUID).symlink_to(dev / "fixture")
    (dev / "disk/by-id/root").symlink_to(dev / "fixture")
    (dev / "mapper/root").symlink_to(dev / "fixture")
    (dev / "block/8:17").symlink_to(dev / "container")
    parent = sysfs / "backing"
    parent.mkdir()
    (parent / "dev").write_text("8:17\n")
    slaves = sysfs / "dev/block/240:5/slaves"
    slaves.mkdir(parents=True)
    (slaves / "backing").symlink_to(parent)
    mapping = sysfs / "dev/block/240:5/dm"
    mapping.mkdir()
    (mapping / "name").write_text("root\n")
    limine = tmp_path / "limine"
    limine.touch(mode=0o755)
    swap = tmp_path / "swap"
    shutil.copy(SCRIPTS / HOOK, scripts / HOOK)
    implementations = [
        scripts / HOOK,
        *(
            source / ".chezmoitemplates/lib" / name
            for name in ("hibernation_swap.py", "hibernation_policy.py", "hibernation_nvidia.py")
        ),
    ]
    for module in implementations:
        text = module.read_text()
        for original, value in (
            ("/etc", etc),
            ("/dev", dev),
            ("/proc", proc),
            ("/sys", sysfs),
            ("/usr/share", tmp_path / "share"),
            ("/usr/bin/limine", limine),
            ("/swap", swap),
        ):
            text = text.replace(f'Path("{original}")', f"Path({str(value)!r})")
        # Waive UID checks only in copied code; every system path is private.
        text = text.replace("if os.geteuid() != 0:", "if False:").replace(
            "if os.geteuid() != 0 or", "if False or"
        )
        module.write_text(text)
    parser = source / ".chezmoitemplates/lib/limine_cmdline.py"
    parser.write_text(
        parser.read_text().replace("/etc/", f"{etc}/").replace("/usr/share/", f"{tmp_path}/share/")
    )
    helper = source / ".chezmoitemplates/lib/policy_files.py"
    helper.write_text(
        helper.read_text()
        .replace("parent.st_uid != 0", "parent.st_uid != os.getuid()")
        .replace("os.chown(stage, 0, 0)", "os.chown(stage, os.getuid(), os.getgid())")
        .replace("== (0, 0, mode)", "== (os.getuid(), os.getgid(), mode)")
    )
    env.update(
        HIBERNATION_SOURCE=str(source),
        FIXTURE=str(tmp_path),
        ROOT_UUID=UUID,
        SUDO_UID=str(os.getuid()),
        SUDO_GID=str(os.getgid()),
    )
    stub(
        env,
        "sudo",
        'case "$1" in -v) exit "${SUDO_STATUS:-0}" ;; -n) shift; unset CHEZMOI_SOURCE_DIR CHEZMOI_WORKING_TREE CHEZMOI_OS_RELEASE_ID DOTFILES_PERSONAL_ENABLED; exec "$@" ;; *) exit 97 ;; esac',
        log=True,
    )
    # Native filesystem tools are never invoked on the development host.
    command = tmp_path / "native-commands.py"
    command.write_text(r"""#!/usr/bin/python3 -B
import json, os, sys
from pathlib import Path
name, args = Path(sys.argv[0]).name, sys.argv[1:]
root = Path(os.environ['FIXTURE']); etc = root / 'etc'; dev = root / 'dev'; swap = root / 'swap'
uuid = os.environ['ROOT_UUID']; luks = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
with Path(os.environ['CALLS']).open('a') as stream: stream.write('\t'.join([name, *args]) + '\t\n')
failure = os.environ.get('FAILURE', '')
def fail(code=23): sys.exit(code)
def output(text): print(text); sys.exit(0)
if name == 'findmnt':
    if args[:3] == ['-n', '-o', 'FSTYPE']:
        if failure == 'filesystem-inspection': fail()
        output(os.environ.get('ROOT_FS', 'btrfs'))
    if args[0] == '--fstab':
        if failure == 'fstab-inspection': fail()
        for line in (etc / 'fstab').read_text().splitlines():
            if line.strip() and not line.lstrip().startswith('#'): print(' '.join(line.split()[:4]))
        sys.exit(0)
    if args[0] == '--nofsroot':
        if failure == 'identity': fail()
        target = ('/unexpected' if failure == 'root-target' else '/') if args[-1] == '/' else str(swap)
        output(f'{target} {dev}/disk/by-id/root btrfs {uuid}')
    if args[2] == 'TARGET,FSTYPE,UUID,FSROOT':
        target = args[-1]
        fsroot = '/@swap' if target == str(swap) else '/'
        if failure == 'wrong-mount': fsroot = '/unexpected'
        output(f'{target} btrfs {uuid} {fsroot}')
    if args[2] == 'TARGET': output(str(swap / 'nested') if failure == 'nested-mount' else str(swap))
elif name == 'hostnamectl':
    if failure == 'chassis-inspection': fail()
    output(os.environ.get('CHASSIS', 'laptop'))
elif name == 'lsblk':
    field, path = (args[2] if '-o' in args else args[1]), Path(args[-1]); identity = '240:5' if os.environ.get('ENCRYPTED') else '8:1'
    if field == 'FSTYPE,UUID,MAJ:MIN': output(f'btrfs {uuid} {identity}')
    if field == 'MAJ:MIN': output('8:17' if path.name == 'container' else '8:18' if path.name == 'other' else identity)
    if field == 'UUID': output(uuid)
    if field == 'TYPE': output('lvm\ncrypt\npart\ndisk' if failure == 'topology' else 'crypt\npart\ndisk' if os.environ.get('ENCRYPTED') else 'part\ndisk')
elif name == 'btrfs':
    if args[:2] == ['filesystem', 'show']:
        if failure == 'fstab-before-snapshot' and not (root / 'concurrent-edit').exists():
            with (etc / 'fstab').open('a') as stream: stream.write(f'UUID=other {swap} btrfs subvol=other 0 0\n')
            (root / 'concurrent-edit').touch()
        output(f'Total devices {2 if failure == "multi-device" else 1} FS bytes used 0\ndevid 1 size 100 used 0 path {dev}/disk/by-uuid/{uuid}')
    if args[:2] == ['subvolume', 'list']:
        if failure == 'fstab-after-snapshot' and not (root / 'concurrent-edit').exists():
            with (etc / 'fstab').open('a') as stream: stream.write(f'UUID=other {swap} btrfs subvol=other 0 0\n')
            (root / 'concurrent-edit').touch()
        if failure == 'subvolume-inspection': fail()
        output('ID 256 gen 1 top level 5 path @swap' if (root / 'subvolume').exists() else '')
    if args[:2] == ['subvolume', 'create']:
        Path(args[-1]).mkdir(); (root / 'subvolume').touch(); sys.exit(0)
    if args[:2] == ['filesystem', 'mkswapfile']:
        if failure == 'create-swap': fail()
        Path(args[-1]).write_text('managed swap contents'); sys.exit(0)
    if args[:2] == ['inspect-internal', 'map-swapfile']:
        if failure == 'offset-command': fail()
        output('invalid' if failure == 'offset-value' else '123')
elif name == 'swapon':
    if failure == 'zswap-inspection' and (etc / 'limine-entry-tool.d/50-hibernation.conf').exists(): fail()
    if args[0].startswith('--show'):
        if failure == 'swap-inspection': fail(int(os.environ.get('FAIL_STATUS', '23')))
        active = os.environ.get('ACTIVE_SWAP', '')
        if (root / 'active').exists(): active += '\n' + str(swap / 'swapfile')
        output(active.strip())
    if failure == 'activate-swap': fail()
    (root / 'active').touch(); sys.exit(0)
elif name == 'mountpoint':
    top = root / 'top-mounted'
    sys.exit(0 if (args[-1] == str(swap) and (root / 'mounted').exists()) or (top.exists() and top.read_text() == args[-1]) else 32)
elif name == 'mount':
    if args[-1] == str(swap): (root / 'mounted').touch()
    else:
        (root / 'top-mounted').write_text(args[-1])
        if failure == 'mount-interruption':
            import signal
            os.kill(os.getppid(), signal.SIGTERM)
    sys.exit(0)
elif name == 'umount':
    if failure == 'unmount': fail()
    child = Path(args[-1]) / '@swap'
    if child.exists(): child.rmdir()
    (root / 'top-mounted').unlink(missing_ok=True)
    sys.exit(0)
elif name == 'systemctl':
    if args[0] == 'list-unit-files':
        if failure == 'unit-inspection': print('bus failure', file=sys.stderr); fail()
        output(os.environ.get('ZRAM_UNITS' if '--type=swap,service' in args else 'SWAP_UNITS', ''))
    if args[0] == 'show': output(os.environ.get('UNIT_DEVICE', '') if args[1] == '--property=What' else os.environ.get('NVIDIA_LOAD', 'loaded'))
    if args == ['daemon-reload']:
        if failure == 'reload': fail()
        sys.exit(0)
elif name == 'blkid': output('crypto_LUKS' if 'TYPE' in args else luks)
elif name == 'cryptsetup': output(f'  type: LUKS2\n  device: {dev}/container')
elif name == 'udevadm':
    if failure == 'udev': fail()
    sys.exit(0)
elif name == 'lspci':
    if args == ['-nn']: output('VGA compatible controller: NVIDIA Corporation' if os.environ.get('NVIDIA') else 'VGA compatible controller: Intel Corporation')
    output('0000:01:00.0 NVIDIA Corporation')
elif name == 'mise':
    config = Path.cwd() / 'mise/config.nvidia-sleep.toml'
    (root / 'nvidia.json').write_text(json.dumps({'config': config.read_text(), 'env': {key: os.environ.get(key) for key in ('MISE_ENV', 'MISE_CONFIG_FILE')}}))
    sys.exit(int(os.environ.get('MISE_STATUS', '0')))
elif name == 'mkinitcpio': fail(97)
print(f'Unexpected fixture command: {name} {args}', file=sys.stderr); fail(97)
""")
    command.chmod(0o755)
    for name in (
        "findmnt",
        "hostnamectl",
        "lsblk",
        "btrfs",
        "swapon",
        "mountpoint",
        "mount",
        "umount",
        "systemctl",
        "blkid",
        "cryptsetup",
        "udevadm",
        "lspci",
        "mise",
        "mkinitcpio",
    ):
        path = Path(env["PATH"]) / name
        path.unlink(missing_ok=True)
        path.symlink_to(command)
    return env


def run_hibernation(hibernation: dict[str, str]) -> subprocess.CompletedProcess[str]:
    script = render_python(hibernation, HOOK, source=Path(hibernation["HIBERNATION_SOURCE"]))
    return run_setup(hibernation, ["/usr/bin/python3", "-B", str(script)])


def managed_swap(hibernation: dict[str, str]) -> Path:
    root = Path(hibernation["FIXTURE"])
    swap = root / "swap"
    swap.mkdir(exist_ok=True)
    path = swap / "swapfile"
    path.write_text("preserve valid swap")
    (root / "subvolume").touch()
    (root / "mounted").touch()
    (root / "active").touch()
    state = Path(hibernation["XDG_STATE_HOME"]) / "chezmoi"
    state.mkdir(parents=True, exist_ok=True)
    (state / "hibernation.swapfile").write_text(f"{UUID} {path} {path.stat().st_ino}\n")
    return path


def hibernation_command(hibernation: dict[str, str], tmp_path: Path) -> list[str]:
    assert CHEZMOI is not None
    source = Path(hibernation["HIBERNATION_SOURCE"])
    config = tmp_path / "chezmoi.json"
    config.write_text(
        json.dumps(
            {
                "data": {"personal": True},
                "scriptEnv": {"DOTFILES_PERSONAL_ENABLED": "1"},
                "interpreters": {"py": {"command": "/usr/bin/python3", "args": ["-B"]}},
            }
        )
    )
    return [
        CHEZMOI,
        "--config",
        str(config),
        "--source",
        str(source),
        "--working-tree",
        str(source.parent),
        "--destination",
        str(tmp_path),
        "apply",
    ]


@pytest.mark.parametrize("encrypted", [False, True], ids=["plain", "luks"])
def test_direct_hibernation_creates_verified_swap_and_reapplies(
    hibernation: dict[str, str], tmp_path: Path, encrypted: bool
) -> None:
    if encrypted:
        hibernation["ENCRYPTED"] = "1"
    command = hibernation_command(hibernation, tmp_path)
    result = run_setup(hibernation, command)
    assert result.returncode == 0, result.stderr
    observed = calls(hibernation)
    result = run_setup(hibernation, command)
    assert result.returncode == 0, result.stderr
    assert calls(hibernation) == observed
    resume = tmp_path / "etc/limine-entry-tool.d/50-hibernation.conf"
    assert (
        resume.read_text()
        == f'KERNEL_CMDLINE[default]+= "hibernate.compressor=lz4 resume=UUID={UUID} resume_offset=123"\n'
    )
    assert (tmp_path / "etc/limine-entry-tool.d/zswap.conf").exists()
    state = Path(hibernation["XDG_STATE_HOME"]) / "chezmoi"
    assert (state / "initramfs.pending").exists()
    assert (tmp_path / "etc/fstab").read_text().count("none swap") == 1
    observed = calls(hibernation)
    assert sum("mkswapfile" in call for call in observed) == 1
    assert sum(call[0] == "swapon" and len(call) == 2 for call in observed) == 1
    # Direct re-execution also verifies actual state without requesting a needless rebuild.
    before = resume.stat().st_mtime_ns
    (state / "initramfs.pending").unlink()
    result = run_hibernation(hibernation)
    assert result.returncode == 0, result.stderr
    assert resume.stat().st_mtime_ns == before
    assert not (state / "initramfs.pending").exists()


@pytest.mark.parametrize(
    "scenario",
    [
        "nonpersonal",
        "bootloader",
        "non-btrfs",
        "desktop",
        "missing-mkinitcpio",
        "filesystem-inspection",
        "chassis-inspection",
    ],
)
def test_hibernation_gates_preserve_isolation_and_failures(
    hibernation: dict[str, str], tmp_path: Path, scenario: str
) -> None:
    if scenario == "bootloader":
        (tmp_path / "limine").chmod(0o644)
    elif scenario == "non-btrfs":
        hibernation["ROOT_FS"] = "ext4"
    elif scenario == "desktop":
        hibernation["CHASSIS"] = "desktop"
    elif scenario == "missing-mkinitcpio":
        (Path(hibernation["PATH"]) / "mkinitcpio").unlink()
    elif scenario.endswith("inspection"):
        hibernation["FAILURE"] = scenario
    if scenario == "nonpersonal":
        script = render_python(
            hibernation, HOOK, personal=False, source=Path(hibernation["HIBERNATION_SOURCE"])
        )
        result = run_setup(hibernation, ["/usr/bin/python3", "-B", str(script)])
        assert calls(hibernation) == []
        assert not (Path(hibernation["XDG_STATE_HOME"]) / "chezmoi").exists()
    else:
        result = run_hibernation(hibernation)
        assert not any(call[0] == "sudo" for call in calls(hibernation))
    assert not (tmp_path / "etc/limine-entry-tool.d/50-hibernation.conf").exists()
    assert result.returncode == (
        23
        if scenario.endswith("inspection")
        else 1
        if scenario in ("missing-mkinitcpio", "bootloader")
        else 0
    ), result.stderr


@pytest.mark.parametrize("ownership", ["matching", "missing", "stale"])
def test_existing_swap_is_reused_only_with_matching_ownership(
    hibernation: dict[str, str], ownership: str
) -> None:
    swap = managed_swap(hibernation)
    original = swap.read_bytes()
    owner = Path(hibernation["XDG_STATE_HOME"]) / "chezmoi/hibernation.swapfile"
    if ownership == "missing":
        owner.unlink()
    elif ownership == "stale":
        owner.write_text(f"{UUID} {swap} 0\n")
    result = run_hibernation(hibernation)
    assert result.returncode == 0, result.stderr
    assert swap.read_bytes() == original
    observed = calls(hibernation)
    assert not any("mkswapfile" in call for call in observed)
    assert (
        Path(hibernation["FIXTURE"]) / "etc/limine-entry-tool.d/50-hibernation.conf"
    ).exists() == (ownership == "matching")


@pytest.mark.parametrize("owner", ["active", "fstab", "unit"])
def test_independent_swap_stays_untouched(
    hibernation: dict[str, str], tmp_path: Path, owner: str
) -> None:
    if owner == "active":
        hibernation["ACTIVE_SWAP"] = "/dev/other"
    elif owner == "fstab":
        with (tmp_path / "etc/fstab").open("a") as stream:
            stream.write("/other/swap none swap defaults 0 0\n")
    else:
        hibernation.update(SWAP_UNITS="custom.swap disabled -", UNIT_DEVICE="/other/swap")
    original = (tmp_path / "etc/fstab").read_bytes()
    result = run_hibernation(hibernation)
    assert result.returncode == 0, result.stderr
    assert (tmp_path / "etc/fstab").read_bytes() == original
    assert not any(
        call[0] in ("btrfs", "mount", "swapon") and (call[0] != "swapon" or len(call) == 2)
        for call in calls(hibernation)
    )
    assert not (tmp_path / "etc/limine-entry-tool.d/zswap.conf").exists()


@pytest.mark.parametrize(
    "failure",
    [
        "identity",
        "root-target",
        "subvolume-inspection",
        "wrong-mount",
        "nested-mount",
        "offset-command",
        "offset-value",
        "unit-inspection",
    ],
)
def test_failed_inspection_never_publishes_resume(
    hibernation: dict[str, str], tmp_path: Path, failure: str
) -> None:
    if failure in ("wrong-mount", "nested-mount"):
        _ = managed_swap(hibernation)
    hibernation["FAILURE"] = failure
    before = (tmp_path / "etc/fstab").read_bytes()
    result = run_hibernation(hibernation)
    assert result.returncode != 0
    assert (tmp_path / "etc/fstab").read_bytes() == before
    assert not (tmp_path / "etc/limine-entry-tool.d/50-hibernation.conf").exists()
    assert not (tmp_path / "etc/limine-entry-tool.d/zswap.conf").exists()


@pytest.mark.parametrize(
    "conflict", ["mount-uuid", "mount-options", "swap-options", "symlink", "hardlink"]
)
def test_swap_conflicts_stop_before_mutation(
    hibernation: dict[str, str], tmp_path: Path, conflict: str
) -> None:
    swap = managed_swap(hibernation)
    fstab = tmp_path / "etc/fstab"
    if conflict == "mount-uuid":
        fstab.write_text(f"UUID=other {swap.parent} btrfs subvol=@swap 0 0\n")
    elif conflict == "mount-options":
        fstab.write_text(f"UUID={UUID} {swap.parent} btrfs subvol=@swap,ro 0 0\n")
    elif conflict == "swap-options":
        fstab.write_text(f"{swap} none swap noauto 0 0\n")
    elif conflict == "symlink":
        swap.rename(tmp_path / "unmanaged")
        swap.symlink_to(tmp_path / "unmanaged")
    else:
        (tmp_path / "unmanaged").hardlink_to(swap)
    original = fstab.read_bytes()
    result = run_hibernation(hibernation)
    assert result.returncode != 0
    assert fstab.read_bytes() == original
    assert not any("mkswapfile" in call for call in calls(hibernation))
    assert not (tmp_path / "etc/limine-entry-tool.d/50-hibernation.conf").exists()


@pytest.mark.parametrize("failure", ["publish", "concurrent-edit", "interrupt", "verify-resume"])
def test_resume_publication_failure_rolls_back_only_its_fstab(
    hibernation: dict[str, str], tmp_path: Path, failure: str
) -> None:
    source = Path(hibernation["HIBERNATION_SOURCE"])
    helper = source / ".chezmoitemplates/lib/policy_files.py"
    helper.write_text(
        helper.read_text().replace(
            "        os.replace(stage, path)",
            """        if path.name == "50-hibernation.conf" and os.environ.get("FAILURE") in ("publish", "concurrent-edit", "interrupt"):
            if os.environ["FAILURE"] == "concurrent-edit":
                with (Path(os.environ["FIXTURE"]) / "etc/fstab").open("a") as stream:
                    stream.write("# independent edit\\n")
            if os.environ["FAILURE"] == "interrupt":
                raise SystemExit(143)
            raise OSError(5, "fixture publication failure")
        os.replace(stage, path)
        if path.name == "50-hibernation.conf" and os.environ.get("FAILURE") == "verify-resume":
            (Path(os.environ["FIXTURE"]) / "etc/default/limine").write_text('KERNEL_CMDLINE[default]="root=UUID=independent"\\n')""",
        )
    )
    hibernation["FAILURE"] = failure
    original = (tmp_path / "etc/fstab").read_text()
    result = run_hibernation(hibernation)
    assert result.returncode == (143 if failure == "interrupt" else 1), result.stderr
    after = (tmp_path / "etc/fstab").read_text()
    assert (
        after == original
        if failure != "concurrent-edit"
        else (
            after.startswith(original)
            and after.endswith("# independent edit\n")
            and "none swap" in after
        )
    )
    assert (tmp_path / "etc/fstab").stat().st_mode & 0o777 == 0o640
    assert not (tmp_path / "etc/limine-entry-tool.d/50-hibernation.conf").exists()
    state = Path(hibernation["XDG_STATE_HOME"]) / "chezmoi"
    assert (state / "initramfs.pending").exists()
    if failure == "verify-resume":
        late = tmp_path / "etc/default/limine"
        assert late.read_text() == 'KERNEL_CMDLINE[default]="root=UUID=independent"\n'
        late.unlink()  # Explicitly resolve the independent conflict before retry.
    hibernation.pop("FAILURE")
    result = run_hibernation(hibernation)
    assert result.returncode == 0, result.stderr
    assert sum("mkswapfile" in call for call in calls(hibernation)) == 1


@pytest.mark.parametrize("status", ["2", "3", "23"])
def test_native_swap_failure_codes_are_not_manual_success(
    hibernation: dict[str, str], status: str
) -> None:
    hibernation.update(FAILURE="swap-inspection", FAIL_STATUS=status)
    result = run_hibernation(hibernation)
    assert result.returncode == int(status), result.stderr
    assert not any(call[0] == "mount" for call in calls(hibernation))


@pytest.mark.parametrize("outcome", ["swap-failure", "boot-conflict", "zswap-failure"])
def test_run_onchange_retries_failures_then_skips_success(
    hibernation: dict[str, str], tmp_path: Path, outcome: str
) -> None:
    command = hibernation_command(hibernation, tmp_path)
    source = Path(hibernation["HIBERNATION_SOURCE"])
    script = source / ".chezmoiscripts/linux" / HOOK
    original = script.read_bytes()
    for number, label in (("02", "order-before"), ("04", "order-after")):
        probe = script.parent / f"run_after_{number}_probe.py"
        probe.write_text(
            "#!/usr/bin/python3 -B\nimport os\nfrom pathlib import Path\n"
            + f'with Path(os.environ["CALLS"]).open("a") as stream: stream.write("{label}\\t\\n")\n'
        )
    late = tmp_path / "etc/default/limine"
    if outcome == "swap-failure":
        hibernation["FAILURE"] = "activate-swap"
    elif outcome == "zswap-failure":
        hibernation["FAILURE"] = "zswap-inspection"
    else:
        late.write_text('KERNEL_CMDLINE[default]="root=UUID=independent"\n')
    for attempt in (1, 2):
        before = len(calls(hibernation))
        result = run_setup(hibernation, command)
        assert result.returncode != 0, result.stderr
        observed = calls(hibernation)[before:]
        assert observed[0] == ["order-before"]
        assert not any(call == ["order-after"] for call in observed)
        assert sum("--configure" in call for call in calls(hibernation)) == attempt
        assert script.read_bytes() == original
        assert (tmp_path / "etc/fstab").read_text().count("none swap") == (
            outcome == "zswap-failure"
        )
        if outcome == "zswap-failure":
            assert (tmp_path / "etc/limine-entry-tool.d/50-hibernation.conf").exists()
            assert (Path(hibernation["XDG_STATE_HOME"]) / "chezmoi/initramfs.pending").exists()
    # Resolve only the native failure / independent Limine conflict.
    if outcome != "boot-conflict":
        hibernation.pop("FAILURE")
    else:
        late.unlink()
    result = run_setup(hibernation, command)
    assert result.returncode == 0, result.stderr
    assert calls(hibernation)[-1] == ["order-after"]
    assert (tmp_path / "etc/limine-entry-tool.d/50-hibernation.conf").exists()
    assert (Path(hibernation["XDG_STATE_HOME"]) / "chezmoi/initramfs.pending").exists()
    assert script.read_bytes() == original
    observed = [call for call in calls(hibernation) if not call[0].startswith("order-")]
    result = run_setup(hibernation, command)
    assert result.returncode == 0, result.stderr
    assert [call for call in calls(hibernation) if not call[0].startswith("order-")] == observed
    # The extracted implementation is a real execution dependency.
    module = source / ".chezmoitemplates/lib/hibernation_policy.py"
    module.write_text(module.read_text() + "\n# Recheck changed implementation.\n")
    result = run_setup(hibernation, command)
    assert result.returncode == 0, result.stderr
    assert sum("--configure" in call for call in calls(hibernation)) == 4
    assert sum("mkswapfile" in call for call in calls(hibernation)) == 1


def test_run_onchange_records_manual_configuration_without_repeating_it(
    hibernation: dict[str, str], tmp_path: Path
) -> None:
    hibernation["ACTIVE_SWAP"] = "/dev/independent"
    command = hibernation_command(hibernation, tmp_path)
    result = run_setup(hibernation, command)
    assert result.returncode == 0, result.stderr
    assert "independently managed" in result.stderr
    observed = calls(hibernation)
    result = run_setup(hibernation, command)
    assert result.returncode == 0, result.stderr
    assert calls(hibernation) == observed
    assert not any(call[0] == "mount" or "mkswapfile" in call for call in observed)
    assert not (tmp_path / "etc/limine-entry-tool.d/50-hibernation.conf").exists()


@pytest.mark.parametrize("gib", [29, 30])
def test_zswap_threshold_is_at_least_30_gib(
    hibernation: dict[str, str], tmp_path: Path, gib: int
) -> None:
    (tmp_path / "proc/meminfo").write_text(f"MemTotal: {gib * 1024**2} kB\n")
    result = run_hibernation(hibernation)
    assert result.returncode == 0, result.stderr
    assert (tmp_path / "etc/limine-entry-tool.d/zswap.conf").exists() == (gib >= 30)


@pytest.mark.parametrize("owner", ["active", "generator", "device", "unit", "service", "fstab"])
def test_available_zram_is_preserved_and_skips_zswap(
    hibernation: dict[str, str], tmp_path: Path, owner: str
) -> None:
    protected: Path | None = None
    if owner == "active":
        hibernation["ACTIVE_SWAP"] = "/dev/zram0"
    elif owner == "generator":
        protected = tmp_path / "etc/systemd/zram-generator.conf"
    elif owner == "device":
        protected = tmp_path / "sys/block/zram0"
    elif owner == "unit":
        hibernation.update(
            SWAP_UNITS="custom.swap generated -",
            ZRAM_UNITS="custom.swap generated -",
            UNIT_DEVICE="/dev/zram0",
        )
    elif owner == "service":
        hibernation["ZRAM_UNITS"] = "systemd-zram-setup@zram0.service enabled -"
    else:
        with (tmp_path / "etc/fstab").open("a") as stream:
            stream.write("/dev/zram0 none swap defaults 0 0\n")
    if protected is not None:
        protected.parent.mkdir(parents=True)
        protected.write_text("preserve configured Zram\n")
    result = run_hibernation(hibernation)
    assert result.returncode == 0, result.stderr
    assert not (tmp_path / "etc/limine-entry-tool.d/zswap.conf").exists()
    assert not any(
        call[0] == "swapoff" or "disable" in call or "stop" in call for call in calls(hibernation)
    )
    if protected is not None:
        assert protected.read_text() == "preserve configured Zram\n"


@pytest.mark.parametrize("owner", ["kernel", "default", "dropin"])
def test_existing_zswap_preferences_and_unrelated_arguments_survive(
    hibernation: dict[str, str], tmp_path: Path, owner: str
) -> None:
    kernel = tmp_path / "etc/kernel/cmdline"
    baseline = kernel.read_text().strip()
    if owner == "kernel":
        path, content = kernel, baseline + " zswap.enabled=0\n"
    elif owner == "default":
        path, content = (
            tmp_path / "etc/limine-entry-tool.d/01-default.conf",
            f'KERNEL_CMDLINE[default]="{baseline} zswap.enabled=1"\n',
        )
    else:
        (tmp_path / "etc/limine-entry-tool.d/01-default.conf").write_text(
            f'KERNEL_CMDLINE[default]="{baseline}"\n'
        )
        path, content = (
            tmp_path / "etc/limine-entry-tool.d/custom.conf",
            'KERNEL_CMDLINE[default]+=" zswap.enabled=1 zswap.enabled=0"\n',
        )
    path.write_text(content)
    result = run_hibernation(hibernation)
    assert result.returncode == 0, result.stderr
    assert path.read_text() == content
    assert not (tmp_path / "etc/limine-entry-tool.d/zswap.conf").exists()
    assert kernel.read_text().startswith(baseline)


@pytest.mark.parametrize("nvidia", [False, True], ids=["intel", "nvidia"])
def test_nvidia_sleep_is_hardware_gated_and_mise_owned(
    hibernation: dict[str, str], tmp_path: Path, nvidia: bool
) -> None:
    if nvidia:
        hibernation["NVIDIA"] = "1"
    result = run_hibernation(hibernation)
    assert result.returncode == 0, result.stderr
    assert (tmp_path / "nvidia.json").exists() == nvidia
    if nvidia:
        record = cast("dict[str, object]", json.loads((tmp_path / "nvidia.json").read_text()))
        content = record["config"]
        assert isinstance(content, str)
        assert 'state = "stopped"' in content
        assert record["env"] == {"MISE_ENV": None, "MISE_CONFIG_FILE": None}
        assert (tmp_path / "etc/tmpfiles.d/nvidia_pm.conf").exists()
        hibernation["MISE_STATUS"] = "23"
        failed = run_hibernation(hibernation)
        assert failed.returncode == 23
    assert not any("start" in call or "restart" in call for call in calls(hibernation))


def test_persistent_resume_preflight_fails_without_swap_changes(
    hibernation: dict[str, str], tmp_path: Path
) -> None:
    late = tmp_path / "etc/default/limine"
    original = 'KERNEL_CMDLINE[default]="root=UUID=independent"\n'
    late.write_text(original)
    result = run_hibernation(hibernation)
    assert result.returncode == 1, result.stderr
    assert "Cannot verify persistent Limine arguments" in result.stderr
    assert late.read_text() == original
    assert not any(call[0] == "mount" or "mkswapfile" in call for call in calls(hibernation))


@pytest.mark.parametrize("unsupported", ["multi-device", "topology"])
def test_verified_unsupported_layouts_require_manual_setup_without_mutation(
    hibernation: dict[str, str], tmp_path: Path, unsupported: str
) -> None:
    hibernation["FAILURE"] = unsupported
    result = run_hibernation(hibernation)
    assert result.returncode == 0, result.stderr
    assert "manually" in result.stderr
    assert not any(call[0] == "mount" or "mkswapfile" in call for call in calls(hibernation))
    assert not (tmp_path / "etc/limine-entry-tool.d/50-hibernation.conf").exists()


def test_interrupted_successful_top_level_mount_is_unmounted_safely(
    hibernation: dict[str, str], tmp_path: Path
) -> None:
    hibernation["FAILURE"] = "mount-interruption"
    result = run_hibernation(hibernation)
    assert result.returncode == 143, result.stderr
    assert not (tmp_path / "top-mounted").exists()
    assert any(call[0] == "umount" for call in calls(hibernation))
    assert not list(tmp_path.glob("chezmoi-btrfs-top-*"))
    assert not (tmp_path / "etc/limine-entry-tool.d/50-hibernation.conf").exists()


@pytest.mark.parametrize("failure", ["fstab-before-snapshot", "fstab-after-snapshot"])
def test_fstab_edits_during_inspection_are_preserved_before_swap_mutation(
    hibernation: dict[str, str], tmp_path: Path, failure: str
) -> None:
    hibernation["FAILURE"] = failure
    result = run_hibernation(hibernation)
    assert result.returncode == 1, result.stderr
    assert "fstab changed" in result.stderr
    assert (
        f"UUID=other {tmp_path / 'swap'} btrfs subvol=other" in (tmp_path / "etc/fstab").read_text()
    )
    assert not any(call[0] == "mount" or "mkswapfile" in call for call in calls(hibernation))
    assert not (tmp_path / "etc/limine-entry-tool.d/50-hibernation.conf").exists()


def test_equivalent_device_and_subvolume_id_entries_are_not_rewritten(
    hibernation: dict[str, str], tmp_path: Path
) -> None:
    swap = managed_swap(hibernation)
    fstab = tmp_path / "etc/fstab"
    original = f"# preserve spelling\n{tmp_path / 'dev/fixture'} {swap.parent} btrfs subvolid=256 0 0\n{swap} swap swap defaults 0 0\n"
    fstab.write_text(original)
    before = fstab.stat().st_mtime_ns
    result = run_hibernation(hibernation)
    assert result.returncode == 0, result.stderr
    assert fstab.read_text() == original
    assert fstab.stat().st_mtime_ns == before
    assert not any("mkswapfile" in call for call in calls(hibernation))


def test_unsafe_swap_ownership_record_preserves_unmanaged_file(
    hibernation: dict[str, str], tmp_path: Path
) -> None:
    state = Path(hibernation["XDG_STATE_HOME"]) / "chezmoi"
    state.mkdir(parents=True)
    unmanaged = tmp_path / "unmanaged-state"
    unmanaged.write_text("preserve unmanaged data\n")
    (state / "hibernation.swapfile").hardlink_to(unmanaged)
    result = run_hibernation(hibernation)
    assert result.returncode == 1, result.stderr
    assert unmanaged.read_text() == "preserve unmanaged data\n"
    assert not (tmp_path / "etc/limine-entry-tool.d/50-hibernation.conf").exists()
