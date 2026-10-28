"""Late rebuild commit boundary and small real-artifact verifier fixtures."""

import hashlib
import json
import os
import pty
import shlex
import shutil
import struct
import subprocess
import sys
from contextlib import suppress
from pathlib import Path
from typing import override

import pytest
from helpers import LIB, SCRIPTS, ScriptCase
from test_setup import calls, run_setup, stub
from test_setup import env as env


@pytest.fixture
def rebuild(env: dict[str, str], tmp_path: Path) -> dict[str, str]:
    source = tmp_path / "boot source/home"
    scripts = source / ".chezmoiscripts/linux"
    scripts.mkdir(parents=True)
    library = source / ".chezmoitemplates/lib"
    shutil.copytree(LIB, library)
    hook = scripts / "run_after_13_initramfs.py"
    hook.write_text(
        (SCRIPTS / hook.name).read_text().replace("if os.geteuid() != 0 or", "if False or")
    )
    etc = tmp_path / "etc"
    (etc / "default").mkdir(parents=True)
    boot = tmp_path / "esp"
    boot.mkdir()
    for name in ("current.efi", "limine.efi", "limine.conf"):
        (boot / name).write_text("fixture artifact\n")
    (etc / "default/limine").write_text(f'ESP_PATH="{boot}"\nENABLE_ENROLL_LIMINE_CONFIG=yes\n')
    certificate = tmp_path / "db.pem"
    certificate.write_text("-----BEGIN CERTIFICATE-----\nfixturecert\n-----END CERTIFICATE-----\n")
    for name in ("limine", "mkinitcpio", "pacman", "lsinitcpio", "limine-enroll-config"):
        stub(env, name, "exit 97")
    enroll_hook = tmp_path / "90-limine-enroll-config"
    enroll_hook.write_bytes((Path(env["PATH"]) / "limine-enroll-config").read_bytes())
    enroll_hook.chmod(0o755)
    module = library / "boot_rebuild.py"
    module.write_text(
        module.read_text().replace(
            'Path("/etc/boot/hooks/post.d/90-limine-enroll-config")', f"Path({str(enroll_hook)!r})"
        )
    )
    module.write_text(
        module.read_text().replace("MAX_OUTPUT = 32 * 1024 * 1024", "MAX_OUTPUT = 128")
    )
    module = library / "limine_config.py"
    module.write_text(
        module.read_text()
        .replace('Path("/etc")', f"Path({str(etc)!r})")
        .replace('Path("/usr/share")', f"Path({str(tmp_path / 'share')!r})")
    )
    (library / "verify_limine_rebuild.py").write_text(REBUILD_VERIFIER)
    env.update(
        CHEZMOI_SOURCE_DIR=str(source),
        DOTFILES_PERSONAL_ENABLED="1",
        SUDO_UID=str(os.getuid()),
        SUDO_GID=str(os.getgid()),
        BOOT=str(boot),
    )
    stub(
        env,
        "findmnt",
        """case "$*" in
    '-rn -o FSTYPE --mountpoint '*) echo vfat ;;
    '-rn -o TARGET,SOURCE,FSTYPE,UUID --mountpoint '*)
        uuid=ABCD-1234
        if [ "${FAILURE:-}" = identity ] && test -f "$HOME/deployed"; then uuid="BCDE-$(cat "$HOME/deployed")"; fi
        printf '%s /dev/fixture-esp vfat %s\\n' "$BOOT" "$uuid" ;;
    *) exit 97 ;;
esac""",
    )
    stub(
        env,
        "limine-install",
        'number=0; if test -f "$HOME/deployed"; then number=$(cat "$HOME/deployed"); fi; printf "%s\\n" "$((number + 1))" > "$HOME/deployed"',
        log=True,
    )
    stub(
        env,
        "limine-mkinitcpio",
        """case "${FAILURE:-}" in
    native) echo 'native rebuild failure' >&2; exit 23 ;;
    rebuild) echo 'ERROR: generation failed'; exit 0 ;;
    overflow) exec /usr/bin/python3 -c 'print("x" * 1024)' ;;
esac
echo 'completed fixture rebuild'
""",
        log=True,
    )
    stub(
        env,
        "sbctl",
        "exec /usr/bin/python3 -B -c " + shlex.quote(REBUILD_SBCTL) + ' "$@"',
        log=True,
    )
    stub(
        env,
        "sudo",
        'case "$1" in -v) exit 0 ;; -n) shift; unset CHEZMOI_SOURCE_DIR CHEZMOI_WORKING_TREE CHEZMOI_OS_RELEASE_ID DOTFILES_PERSONAL_ENABLED; exec "$@" ;; *) exit 97 ;; esac',
        log=True,
    )
    return env


def rebuild_command(env: dict[str, str]) -> list[str]:
    return [
        "/usr/bin/python3",
        "-B",
        str(Path(env["CHEZMOI_SOURCE_DIR"]) / ".chezmoiscripts/linux/run_after_13_initramfs.py"),
    ]


@pytest.mark.parametrize(
    "failure",
    [
        "native",
        "rebuild",
        "verify",
        "enrollment",
        "signature",
        "identity",
        "request-changed",
        "overflow",
    ],
)
def test_failed_boot_commit_preserves_request_and_retries_unchanged(
    rebuild: dict[str, str], tmp_path: Path, failure: str
) -> None:
    pending = tmp_path / "state/chezmoi/initramfs.pending"
    pending.parent.mkdir(parents=True, mode=0o700)
    pending.write_text("same request\n")
    before = pending.read_bytes()
    artifacts = {path.name: path.read_bytes() for path in (tmp_path / "esp").iterdir()}
    rebuild["FAILURE"] = failure
    command = rebuild_command(rebuild)
    for _ in range(2):
        result = run_setup(rebuild, command)
        assert result.returncode == (23 if failure == "native" else 1), result.stderr
        assert pending.read_bytes() == before
        assert {path.name: path.read_bytes() for path in (tmp_path / "esp").iterdir()} == artifacts
    rebuild.pop("FAILURE")
    result = run_setup(rebuild, command)
    assert result.returncode == 0, result.stderr
    assert not pending.exists()
    observed = calls(rebuild)
    result = run_setup(rebuild, command)
    assert result.returncode == 0, result.stderr
    assert calls(rebuild) == observed
    assert observed[-1][0] == "sbctl" and observed[-1][1:3] == ["--json", "verify"]


def test_fresh_secure_boot_initializes_before_config_and_preserves_initialized_keys(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    from lib import secure_boot

    state = tmp_path / "state"
    state.mkdir(mode=0o700)
    certificate = tmp_path / "db.pem"
    vendor = tmp_path / "vendor"
    vendor.write_text("Fixture firmware")
    status = {"installed": False, "setup_mode": True, "secure_boot": False}
    recorded: list[list[str]] = []
    fail_config = False

    def run(command: list[str], **_kwargs: object) -> subprocess.CompletedProcess[str]:
        recorded.append(command)
        output = ""
        if command == ["sbctl", "--json", "status"]:
            output = json.dumps(status)
        elif command == ["sbctl", "create-keys"]:
            assert not status["installed"]
            assert (state / "initramfs.pending").is_file()
            status["installed"] = True
            certificate.write_text(
                "-----BEGIN CERTIFICATE-----\nfixturecert\n-----END CERTIFICATE-----\n"
            )
        elif command == ["sbctl", "--json", "setup", "--print-config"]:
            if not status["installed"] or fail_config:
                raise subprocess.CalledProcessError(
                    23, command, stderr="sbctl configuration unavailable"
                )
            output = json.dumps({"keys": {"db": {"pubkey": str(certificate)}}})
        elif command[:2] == ["sbctl", "enroll-keys"]:
            assert status["setup_mode"] and not status["secure_boot"]
            assert (state / "initramfs.pending").is_file()
            status["setup_mode"] = False
        elif command == ["sbctl", "--json", "list-enrolled-keys"]:
            assert not status["setup_mode"]
            output = '{"DB":[{"Raw":"fixturecert"}]}'
        else:
            pytest.fail(f"Unexpected Secure Boot command: {command}")
        return subprocess.CompletedProcess(command, 0, stdout=output, stderr="")

    def configure(settings: dict[str, str], requested: Path) -> None:
        assert settings == {"ENABLE_VERIFICATION": "yes", "ENABLE_ENROLL_LIMINE_CONFIG": "yes"}
        assert requested == state
        assert (state / "initramfs.pending").is_file()
        recorded.append(["configure-limine-settings"])

    def which(command: str) -> str:
        return f"/fixture/{command}"

    monkeypatch.setenv("SUDO_UID", str(os.getuid()))
    monkeypatch.setenv("SUDO_GID", str(os.getgid()))
    monkeypatch.setattr(shutil, "which", which)
    monkeypatch.setattr(secure_boot, "boot_directory", lambda: tmp_path / "esp")
    monkeypatch.setattr(secure_boot, "VENDOR", vendor)
    monkeypatch.setattr(subprocess, "run", run)
    monkeypatch.setattr(secure_boot, "configure_limine_settings", configure)
    secure_boot.configure_secure_boot(state)
    assert recorded[0] == ["sbctl", "--json", "status"]
    assert recorded.index(["sbctl", "create-keys"]) < recorded.index(
        ["sbctl", "--json", "setup", "--print-config"]
    )
    enrollment = ["sbctl", "enroll-keys", "--microsoft", "--ignore-immutable", "--firmware-builtin"]
    assert recorded.index(["sbctl", "--json", "setup", "--print-config"]) < recorded.index(
        enrollment
    )
    before = certificate.read_bytes()
    secure_boot.configure_secure_boot(state)
    fail_config = True
    with pytest.raises(subprocess.CalledProcessError) as failure:
        secure_boot.configure_secure_boot(state)
    assert failure.value.returncode == 23
    assert recorded.count(["sbctl", "create-keys"]) == 1
    assert recorded.count(enrollment) == 1
    assert certificate.read_bytes() == before


class SecureBootTests(ScriptCase):
    @override
    def setUp(self) -> None:
        super().setUp()
        self.etc = self.directory / "etc"
        self.config = self.etc / "default/limine"
        self.config.parent.mkdir(parents=True)
        self.boot = self.directory / "esp"
        self.boot.mkdir()
        (self.directory / "sys/firmware/efi/efivars").mkdir(parents=True)
        self.vendor = self.directory / "sys/class/dmi/id/sys_vendor"
        self.vendor.parent.mkdir(parents=True)
        self.vendor.write_text("Fixture firmware\n")
        self.certificate = self.directory / "db.pem"
        self.certificate.write_text(
            "-----BEGIN CERTIFICATE-----\nfixturecert\n-----END CERTIFICATE-----\n"
        )
        self.marker = self.directory / "state/chezmoi/initramfs.pending"
        self.enrolled = self.directory / "enrolled"
        self.env.update(
            DOTFILES_DISTRO_FAMILY="arch",
            MARKER=str(self.marker),
            ENROLLED=str(self.enrolled),
            BOOT=str(self.boot),
            FAILURE="",
            STATE='{"installed":true,"setup_mode":false,"secure_boot":true}',
            POST_STATE='{"installed":true,"setup_mode":false,"secure_boot":false}',
            KEY_CONFIG=json.dumps(
                {
                    "keys": {"db": {"pubkey": str(self.certificate)}},
                }
            ),
            ENROLLED_KEYS='{"DB":[{"Raw":"fixturecert"}]}',
        )
        for command in ("limine", "mkinitcpio", "limine-enroll-config", "limine-update"):
            self.stub(command, "exit 97")
        self.stub("sed", 'exec /usr/bin/sed "$@"')
        self.stub("findmnt", '[ "$*" = "-rn -o FSTYPE --mountpoint $BOOT" ] || exit 97; echo vfat')
        self.stub(
            "sudo",
            r'''case "$1" in
    bash) [ "$FAILURE" != read ] || exit 23 ;;
    sbctl|awk|grep|sed) ;;
    *) exit 97 ;;
esac
for arg do
    case "$arg" in /*) case "$arg" in "$HOME"/*) ;; *) exit 97 ;; esac ;; esac
done
exec "$@"''',
        )
        self.stub(
            "sbctl",
            r"""case "$*" in
    '--json status')
        if [ -f "$ENROLLED" ]; then printf '%s\n' "$POST_STATE"; else printf '%s\n' "$STATE"; fi ;;
    '--json setup --print-config') printf '%s\n' "$KEY_CONFIG" ;;
    '--json list-enrolled-keys') printf '%s\n' "$ENROLLED_KEYS" ;;
    create-keys)
        [ -f "$MARKER" ] || exit 97
        [ "$FAILURE" != create ] || exit 23 ;;
    enroll-keys\ *)
        [ -f "$MARKER" ] || exit 97
        [ "$FAILURE" != enroll ] || exit 23
        touch "$ENROLLED" ;;
    *) exit 97 ;;
esac""",
            log=True,
        )
        self.reset()

    def security(self) -> subprocess.CompletedProcess[str]:
        library = self.directory / "source/.chezmoitemplates/lib"
        library.mkdir(parents=True, exist_ok=True)
        for path in LIB.glob("*.py"):
            shutil.copy(path, library / path.name)
        policy = library / "policy_files.py"
        policy.write_text(
            policy.read_text().replace("parent.st_uid != 0", "parent.st_uid != os.getuid()")
        )
        self.env.update(SUDO_UID=str(os.getuid()), SUDO_GID=str(os.getgid()))
        driver = self.directory / "secure.py"
        driver.write_text(SECURITY_DRIVER + "\nsecure_boot.configure_secure_boot(state)\n")
        return self.run_process(
            [sys.executable, "-B", str(driver)], name="Secure Boot configuration"
        )

    def reset(self, verification: str = "yes", enrollment: str = "yes") -> None:
        self.calls.unlink(missing_ok=True)
        self.marker.unlink(missing_ok=True)
        self.enrolled.unlink(missing_ok=True)
        self.config.write_text(
            f"ESP_PATH={self.boot}\nENABLE_VERIFICATION={verification}\n"
            + f"ENABLE_ENROLL_LIMINE_CONFIG={enrollment}\n"
        )

    def test_unchanged_trusted_setup_preserves_config_and_existing_pending_request(self) -> None:
        for pending in (False, True):
            with self.subTest(pending=pending):
                self.reset()
                if pending:
                    self.marker.parent.mkdir(parents=True, exist_ok=True)
                    self.marker.write_bytes(b"existing request")
                before = (
                    self.config.read_bytes(),
                    self.config.stat().st_ino,
                    self.config.stat().st_mtime_ns,
                )
                marker_before = self.marker.stat().st_mtime_ns if pending else None
                result = self.security()
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(
                    (
                        self.config.read_bytes(),
                        self.config.stat().st_ino,
                        self.config.stat().st_mtime_ns,
                    ),
                    before,
                )
                self.assertEqual(self.marker.exists(), pending)
                if pending:
                    self.assertEqual(self.marker.read_bytes(), b"existing request")
                    self.assertEqual(self.marker.stat().st_mtime_ns, marker_before)

    def test_each_changed_setting_requests_rebuild_before_the_real_configuration_write(
        self,
    ) -> None:
        for key in ("ENABLE_VERIFICATION", "ENABLE_ENROLL_LIMINE_CONFIG"):
            with self.subTest(key=key):
                self.reset(
                    "no" if key == "ENABLE_VERIFICATION" else "yes",
                    "no" if key == "ENABLE_ENROLL_LIMINE_CONFIG" else "yes",
                )
                result = self.security()
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertTrue(self.marker.is_file())
                self.assertNotIn("=no", self.config.read_text())
                self.assertEqual(
                    [call for call in self.logged_calls() if call[0] == "update"], [["update", key]]
                )

    def test_key_creation_and_enrollment_queue_rebuild_with_unchanged_settings(self) -> None:
        for installed, vendor in ((False, "Fixture"), (True, "Fixture"), (True, "ASUS")):
            with self.subTest(installed=installed, vendor=vendor):
                self.reset()
                self.vendor.write_text(vendor + "\n")
                self.env.update(
                    STATE=json.dumps(
                        {"installed": installed, "setup_mode": True, "secure_boot": False}
                    )
                )
                before = self.config.stat().st_ino
                result = self.security()
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertTrue(self.marker.is_file())
                self.assertEqual(["sbctl", "create-keys"] in self.logged_calls(), not installed)
                flags = ["sbctl", "enroll-keys", "--microsoft", "--ignore-immutable"]
                if vendor == "Fixture":
                    flags.append("--firmware-builtin")
                self.assertIn(flags, self.logged_calls())
                self.assertEqual(self.config.stat().st_ino, before)
                self.assertFalse(any(call[0] == "update" for call in self.logged_calls()))

    def test_configuration_write_failures_keep_rebuild_intent(self) -> None:
        for key in ("ENABLE_VERIFICATION", "ENABLE_ENROLL_LIMINE_CONFIG"):
            with self.subTest(key=key):
                self.reset("no", "no")
                self.env["FAILURE"] = "write-" + key
                result = self.security()
                self.assertEqual(result.returncode, 1, result.stderr)
                self.assertTrue(self.marker.is_file())
                self.assertIn("Failed to configure " + key, result.stderr)

    def test_key_operation_and_request_failures_stop_safely(self) -> None:
        for failure, installed in (("create", False), ("enroll", True)):
            with self.subTest(failure=failure):
                self.reset()
                self.env.update(
                    FAILURE=failure,
                    STATE=json.dumps(
                        {"installed": installed, "setup_mode": True, "secure_boot": False}
                    ),
                )
                before = self.config.read_bytes()
                result = self.security()
                self.assertEqual(result.returncode, 1, result.stderr)
                self.assertTrue(self.marker.is_file())
                self.assertEqual(self.config.read_bytes(), before)
                self.assertFalse(self.enrolled.exists())
        for mutation in ("write", "create", "enroll"):
            with self.subTest(request_failure_before=mutation):
                self.reset("no" if mutation == "write" else "yes")
                blocked = self.directory / "blocked-state"
                blocked.write_text("not a directory")
                self.env.update(
                    FAILURE="",
                    XDG_STATE_HOME=str(blocked),
                    MARKER=str(blocked / "chezmoi/initramfs.pending"),
                    STATE=json.dumps(
                        {
                            "installed": mutation != "create",
                            "setup_mode": mutation != "write",
                            "secure_boot": False,
                        }
                    ),
                )
                result = self.security()
                self.assertEqual(result.returncode, 1, result.stderr)
                self.assertFalse(
                    any(
                        call[0] == "update" or call[1:2] in (["create-keys"], ["enroll-keys"])
                        for call in self.logged_calls()
                    )
                )

    def test_invalid_keys_and_unsafe_firmware_states_remain_rejected(self) -> None:
        cases = (
            (
                {"STATE": '{"installed":"true","setup_mode":false,"secure_boot":true}'},
                "Unexpected sbctl status",
            ),
            ({"KEY_CONFIG": "{}"}, "usable db public certificate"),
            ({"ENROLLED_KEYS": '{"DB":[{"Raw":"untrusted"}]}'}, "not enrolled"),
            (
                {"STATE": '{"installed":true,"setup_mode":true,"secure_boot":true}'},
                "Disable Secure Boot",
            ),
            (
                {"STATE": '{"installed":false,"setup_mode":false,"secure_boot":false}'},
                "Enter UEFI Setup Mode",
            ),
        )
        defaults = {key: self.env[key] for values, _ in cases for key in values}
        for changes, error in cases:
            with self.subTest(error=error):
                self.reset()
                self.env.update(defaults)
                self.env.update(changes)
                result = self.security()
                self.assertEqual(result.returncode, 1, result.stderr)
                self.assertIn(error, result.stderr)
                self.assertFalse(self.marker.exists())
                self.assertFalse(any(call[0] == "update" for call in self.logged_calls()))


class RebuildVerifierTests(ScriptCase):
    @override
    def setUp(self) -> None:
        super().setUp()
        self.machine = "0123456789abcdef" * 2
        machine_file = self.directory / "machine-id"
        machine_file.write_text(self.machine)
        modules = self.directory / "modules"
        kernel_dir = modules / "fixture-version"
        kernel_dir.mkdir(parents=True)
        (kernel_dir / "modules.builtin").write_text("fixture\n")
        self.kernel = kernel_dir / "vmlinuz"
        self.kernel.write_bytes(b"fixture kernel")
        self.boot = self.directory / "esp"
        self.boot.mkdir()
        (self.boot / "vmlinuz").write_bytes(self.kernel.read_bytes())
        (self.boot / "initramfs.img").write_bytes(b"fixture initramfs")
        self.stub("pacman", "echo linux")
        self.stub(
            "lsinitcpio",
            """[ "$(cat "$4")" = 'fixture initramfs' ] || exit 23
printf '%s\\n' init usr/lib/modules/fixture-version/kernel/fixture.ko""",
        )
        self.verifier = (
            (LIB / "verify_limine_rebuild.py")
            .read_text()
            .replace("/etc/machine-id", str(machine_file))
            .replace("/usr/lib/modules", str(modules))
        )
        self.current = (
            "//Kernel\ncomment: kernel-id=linux\nprotocol: linux\n"
            "kernel_path: boot():/vmlinuz\nmodule_path: boot():/initramfs.img\n"
        )
        self.uki_entry = (
            "//Kernel\ncomment: kernel-id=linux\nprotocol: efi\nimage_path: boot():/fixture.efi\n"
        )
        self.history = (
            "//Snapshots\n///Old snapshot\n////Kernel\ncomment: kernel-id=linux\n"
            "protocol: linux\nkernel_path: boot():/old/missing-kernel\n"
        )

    def write_uki(
        self, kernel: bytes = b"fixture kernel", initrd: bytes = b"fixture initramfs"
    ) -> None:
        # One fixed PE32+ image with two bounded, padded sections; never executable.
        image = bytearray(0x600)
        image[:2] = b"MZ"
        struct.pack_into("<I", image, 60, 0x80)
        image[0x80:0x84] = b"PE\0\0"
        struct.pack_into("<H", image, 0x86, 2)
        struct.pack_into("<H", image, 0x94, 112)
        struct.pack_into("<H", image, 0x98, 0x20B)
        struct.pack_into("<II", image, 0xD0, 0x3000, 0x200)
        for index, (name, payload) in enumerate(((b".linux", kernel), (b".initrd", initrd))):
            header = 0x108 + index * 40
            raw = 0x200 + index * 0x200
            struct.pack_into(
                "<8sIIII", image, header, name, len(payload), 0x1000 + index * 0x1000, 0x200, raw
            )
            image[raw : raw + len(payload)] = payload
        (self.boot / "fixture.efi").write_bytes(image)

    def verify(self, entries: str, *, uki: bool = False) -> subprocess.CompletedProcess[str]:
        (self.boot / "limine.conf").write_text(
            f"/+Fixture\ncomment: machine-id={self.machine}\n" + entries
        )
        expected = {
            "machine": self.machine,
            "fallback": "no",
            "uki": uki,
            "kernels": {
                "linux": [
                    "fixture-version",
                    str(self.kernel),
                    hashlib.blake2b(self.kernel.read_bytes()).hexdigest(),
                ]
            },
        }
        output = (
            (
                "Building UKI for linux (fixture-version)\n"
                "==> Initcpio image generation successful\n"
                "==> Unified kernel image generation successful\n"
            )
            if uki
            else (
                "Building initramfs for linux (fixture-version)\n"
                "==> Initcpio image generation successful\n"
            )
        )
        return self.run_process(
            [
                sys.executable,
                "-I",
                "-B",
                "-c",
                self.verifier,
                "verify",
                str(self.boot),
                "no",
                "yes" if uki else "no",
                json.dumps(expected),
            ],
            name="rebuild verifier",
            input=output,
        )

    def test_current_artifacts_are_verified_independently_of_snapshot_history(self) -> None:
        for uki in (False, True):
            with self.subTest(protocol="UKI" if uki else "Linux"):
                self.write_uki()
                entries = self.uki_entry if uki else self.current
                result = self.verify(entries + self.history, uki=uki)
                self.assertEqual(result.returncode, 0, result.stderr)

    def test_missing_current_entry_or_stale_artifact_cannot_verify_a_rebuild(self) -> None:
        result = self.verify(self.history)
        self.assertNotEqual(result.returncode, 0, result.stderr)
        self.assertIn("missing or ambiguous", result.stderr)
        (self.boot / "vmlinuz").write_bytes(b"stale kernel")
        result = self.verify(self.current + self.history)
        self.assertNotEqual(result.returncode, 0, result.stderr)
        self.assertIn("deployed kernel differs", result.stderr)
        for failure in ("stale-kernel", "wrong-initrd", "truncated-initrd"):
            with self.subTest(protocol="UKI", failure=failure):
                self.write_uki(
                    kernel=b"stale kernel" if failure == "stale-kernel" else b"fixture kernel",
                    initrd=b"wrong initramfs"
                    if failure == "wrong-initrd"
                    else b"fixture initramfs",
                )
                if failure == "truncated-initrd":
                    image = self.boot / "fixture.efi"
                    image.write_bytes(image.read_bytes()[:0x480])
                result = self.verify(self.uki_entry + self.history, uki=True)
                self.assertNotEqual(result.returncode, 0, result.stderr)
                diagnostic = {
                    "stale-kernel": "UKI kernel differs",
                    "wrong-initrd": "verification failed",
                    "truncated-initrd": "out-of-bounds PE section",
                }[failure]
                self.assertIn(diagnostic, result.stderr)

    def test_enrolled_checksum_matches_final_config_without_modifying_efi(self) -> None:
        config = self.boot / "limine.conf"
        config.write_text("timeout: 5\n/+Fixture\n")
        checksum = hashlib.blake2b(config.read_bytes()).hexdigest().encode()
        slot = b"++CONFIG_B2SUM_SIGNATURE++"
        image = self.boot / "EFI/limine/limine_x64.efi"
        image.parent.mkdir(parents=True)
        verifier = self.verifier.replace("arch = os.uname().machine", "arch = 'x86_64'")
        for case, payload in (
            ("matching", slot + checksum),
            ("stale", slot + b"f" * 128),
            ("zeroed", slot + b"0" * 128),
            ("missing", b"no checksum slot"),
            ("duplicate", slot + checksum + slot + checksum),
        ):
            with self.subTest(checksum=case):
                original = b"fixture EFI prefix" + payload + b"fixture suffix"
                image.write_bytes(original)
                result = self.run_process(
                    [sys.executable, "-I", "-B", "-c", verifier, "enrollment", str(self.boot)],
                    name="Limine enrolled checksum verifier",
                )
                self.assertEqual(result.returncode, 0 if case == "matching" else 1, result.stderr)
                self.assertEqual(image.read_bytes(), original)
                self.assertEqual(config.read_text(), "timeout: 5\n/+Fixture\n")


@pytest.mark.parametrize("missing", ["limine", "mkinitcpio"])
def test_missing_rebuild_prerequisite_fails_without_clearing_request(
    rebuild: dict[str, str], tmp_path: Path, missing: str
) -> None:
    (Path(rebuild["PATH"]) / missing).unlink()
    command = rebuild_command(rebuild)
    result = run_setup(rebuild, command)
    assert result.returncode == 0, result.stderr
    pending = tmp_path / "state/chezmoi/initramfs.pending"
    pending.write_text("unchanged request\n")
    for _ in range(2):
        result = run_setup(rebuild, command)
        assert result.returncode == 127, result.stderr
        assert pending.read_text() == "unchanged request\n"
    rebuild["DOTFILES_PERSONAL_ENABLED"] = "0"
    assert run_setup(rebuild, command).returncode == 0
    assert pending.exists()


SECURITY_DRIVER = r"""import os, sys
from pathlib import Path
home = Path(os.environ['HOME']); sys.path.insert(0, str(home / 'source/.chezmoitemplates'))
from lib import secure_boot, limine_config, policy_files
limine_config.ETC = home / 'etc'; limine_config.SHARE = home / 'share'
secure_boot.VENDOR = home / 'sys/class/dmi/id/sys_vendor'
state = Path(os.environ['XDG_STATE_HOME']) / 'chezmoi'
state.mkdir(parents=True, exist_ok=True); state.chmod(0o700)
original = policy_files.replace_config
def replace(path, expected, content, metadata, mode=None):
    if path == home / 'etc/default/limine':
        previous = path.read_text()
        for key in ('ENABLE_VERIFICATION','ENABLE_ENROLL_LIMINE_CONFIG'):
            if key + '=no' in previous and (key + '="yes"') in content.decode():
                with Path(os.environ['CALLS']).open('a') as stream: stream.write('update\t' + key + '\t\n')
                assert (state / 'initramfs.pending').is_file()
                if os.environ.get('FAILURE') == 'write-' + key: raise OSError('Failed to configure ' + key)
    return original(path, expected, content, metadata, mode)
policy_files.replace_config = replace
"""


@pytest.mark.parametrize("personal, failure", [(True, 0), (True, 23), (False, 0)])
def test_secure_boot_personal_profile_provisions_without_an_enrollment_prompt(
    env: dict[str, str], tmp_path: Path, personal: bool, failure: int
) -> None:
    from test_setup import calls, render_python, run_setup, stub

    env.update(NOCONFIRM="1", CI="1", DOTFILES_DISTRO_FAMILY="arch", FAILURE=str(failure))
    limine = tmp_path / "limine"
    limine.touch(mode=0o755)
    efivars = tmp_path / "efivars"
    efivars.mkdir()
    stub(env, "mkinitcpio", "exit 97")
    stub(
        env,
        "sudo",
        """case "$1" in
    -v) exit 0 ;;
    -n)
        shift
        [ "$#" = 7 ] && [ "$2" = -B ] && [ "$4" = --configure ] && [ "$7" = 1 ] || exit 97
        if [ "$FAILURE" != 0 ]; then echo 'fixture sbctl failure' >&2; exit "$FAILURE"; fi ;;
    *) exit 97 ;;
esac""",
        log=True,
    )
    script = render_python(env, "run_onchange_after_05_secure_boot.py.tmpl", personal=personal)
    script.write_text(
        script.read_text()
        .replace('Path("/usr/bin/limine")', f"Path({str(limine)!r})")
        .replace('Path("/sys/firmware/efi/efivars")', f"Path({str(efivars)!r})")
    )
    result = run_setup(env, ["/usr/bin/python3", "-B", str(script)])
    assert result.returncode == failure, result.stderr
    observed = calls(env)
    if personal:
        assert observed[0] == ["sudo", "-v"]
        assert len(observed) == 2
        assert observed[1][-4:] == [
            "--configure",
            str(tmp_path / "state/chezmoi"),
            env["CHEZMOI_SOURCE_DIR"],
            "1",
        ]
        if failure:
            assert "fixture sbctl failure" in result.stderr
    else:
        assert not observed
        assert not (tmp_path / "state").exists()
    assert not (tmp_path / "state/chezmoi/initramfs.pending").exists()


REBUILD_VERIFIER = r"""import os
from pathlib import Path

def record(label):
    assert 'CHEZMOI_SOURCE_DIR' not in os.environ
    assert 'DOTFILES_PERSONAL_ENABLED' not in os.environ
    pending = Path(os.environ['HOME']) / 'state/chezmoi/initramfs.pending'
    assert pending.is_file()
    with Path(os.environ['CALLS']).open('a') as stream: stream.write(label + '\t\n')
    if os.environ.get('FAILURE') == label: raise ValueError('Fixture ' + label + ' failure')
def inventory(fallback, uki):
    record('inventory')
    return {}
def verify(boot, expected, output, fallback, uki):
    record('verify')
    if os.environ.get('FAILURE') == 'request-changed':
        pending = Path(os.environ['HOME']) / 'state/chezmoi/initramfs.pending'
        pending.chmod(0o640 if pending.stat().st_mode & 0o777 == 0o600 else 0o600)
    return [boot / 'current.efi']
def verify_enrollment(boot):
    record('enrollment')
    return boot / 'limine.efi'
"""

REBUILD_SBCTL = r"""import json, os, sys
from pathlib import Path
args = sys.argv[1:]; home = Path.home()
if args == ['setup','--print-state','--json']: print('{"installed":true}')
elif args == ['--json','setup','--print-config']: print(json.dumps({'keys':{'db':{'pubkey':str(home / 'db.pem')}}}))
elif args == ['--json','list-enrolled-keys']: print('{"DB":[{"Raw":"fixturecert"}]}')
elif args[:2] == ['--json','verify']:
    print(json.dumps([{'file_name':name,'is_signed':0 if os.environ.get('FAILURE') == 'signature' else 1} for name in args[2:]]))
else: sys.exit(97)
"""


@pytest.mark.parametrize("answer", [None, "n", "yes"], ids=["unattended", "declined", "confirmed"])
def test_finalization_reboots_only_after_terminal_confirmation(
    env: dict[str, str], answer: str | None
) -> None:
    from test_setup import render_python

    stub(env, "sbctl", "echo '{\"secure_boot\":false}'")
    stub(env, "systemctl", "exit 0", log=True)
    script = render_python(env, "run_onchange_after_99_finalize.py")
    command = ["/usr/bin/python3", "-B", str(script)]
    if answer is None:
        env["NOCONFIRM"] = "1"
        result = run_setup(env, command)
    else:
        setsid = shutil.which("setsid")
        assert setsid is not None
        master, slave = pty.openpty()
        try:
            _ = os.write(master, (answer + "\n").encode())
            result = subprocess.run(
                [setsid, "--ctty", "--wait", *command],
                stdin=slave,
                capture_output=True,
                text=True,
                env=env,
                check=False,
                timeout=15,
            )
        finally:
            os.close(slave)
            os.close(master)
    assert result.returncode == 0, result.stderr
    assert calls(env) == ([["systemctl", "reboot", "--firmware-setup"]] if answer == "yes" else [])


def test_interrupted_limine_command_stops_descendants_after_the_leader_exits(
    tmp_path: Path,
) -> None:
    import signal
    import time

    spawner = tmp_path / "spawn.py"
    leader_file, child_file = tmp_path / "leader", tmp_path / "child"
    spawner.write_text(
        "import os, signal, time\nfrom pathlib import Path\n"
        + f"Path({str(leader_file)!r}).write_text(str(os.getpid()))\n"
        + "if os.fork() == 0:\n"
        + "    signal.signal(signal.SIGTERM, signal.SIG_IGN)\n"
        + f"    target = Path({str(child_file)!r})\n"
        + "    stage = target.with_suffix('.ready')\n"
        + "    stage.write_text(str(os.getpid()))\n"
        + "    os.replace(stage, target)\n"
        + "    while True: time.sleep(1)\n"
        + f"while not Path({str(child_file)!r}).exists(): time.sleep(0.01)\n"
    )
    driver = tmp_path / "checked.py"
    driver.write_text(
        "import signal, sys\n"
        + f"sys.path.insert(0, {str(LIB.parent)!r})\n"
        + "from lib.boot_rebuild import checked_limine_command\n"
        + "def stop(*args): raise SystemExit(143)\n"
        + "signal.signal(signal.SIGTERM, stop)\n"
        + f"checked_limine_command([sys.executable, '-B', {str(spawner)!r}])\n"
    )
    process = subprocess.Popen(
        [sys.executable, "-B", str(driver)], stdout=subprocess.PIPE, stderr=subprocess.PIPE
    )
    child = None
    try:
        deadline = time.monotonic() + 5
        while not child_file.exists() and time.monotonic() < deadline:
            time.sleep(0.01)
        assert child_file.exists(), "fixture descendant did not start"
        child = int(child_file.read_text())
        leader = int(leader_file.read_text())
        while (
            Path(f"/proc/{leader}/stat").exists()
            and Path(f"/proc/{leader}/stat").read_text().split()[2] != "Z"
            and time.monotonic() < deadline
        ):
            time.sleep(0.01)
        process.terminate()
        _, diagnostic = process.communicate(timeout=10)
        assert process.returncode == 143, diagnostic.decode()
        status = Path(f"/proc/{child}/stat")
        assert not status.exists() or status.read_text().split()[2] == "Z", (
            "boot helper descendant survived interruption"
        )
    finally:
        if child is not None:
            with suppress(ProcessLookupError):
                os.kill(child, signal.SIGKILL)
        if process.poll() is None:
            process.terminate()
        try:
            _ = process.communicate(timeout=10)
        except subprocess.TimeoutExpired:
            if leader_file.exists() and leader_file.read_text().isdigit():
                with suppress(ProcessLookupError):
                    os.killpg(int(leader_file.read_text()), signal.SIGKILL)
            process.kill()
            _ = process.communicate(timeout=5)
