"""Late rebuild commit boundary and small real-artifact verifier fixtures."""

import hashlib
import json
import shlex
import struct
import subprocess
import sys
from typing import override

from helpers import LIB, SCRIPTS, ScriptCase


class InitramfsTests(ScriptCase):
    def test_pending_request_is_cleared_only_after_a_verified_rebuild(self) -> None:
        boot = self.directory / "esp"
        boot.mkdir()
        marker = self.directory / "state/chezmoi/initramfs.pending"
        marker.parent.mkdir(parents=True)
        self.env.update(BOOT=str(boot), MARKER=str(marker))
        self.stub("limine", "exit 97")
        self.stub("limine-install", "exit 0", log=True)
        self.stub(
            "limine-mkinitcpio",
            """
[ -f "$MARKER" ] || exit 97
if [ "$FAILURE" = rebuild ]; then echo 'ERROR: generation failed'; fi
exit 0""",
            log=True,
        )
        self.stub("limine-enroll-config", "exit 97")
        hook = self.directory / "post.d/90-limine-enroll-config"
        hook.parent.mkdir()
        hook.write_bytes((self.bin / "limine-enroll-config").read_bytes())
        hook.chmod(0o755)
        self.stub(
            "jq",
            """[ "$*" = '-e .installed == true' ] &&
[ "$(cat)" = '{"installed":true}' ]""",
        )
        # Exercise orchestration; the verifier itself runs against real fixtures below.
        self.stub(
            "sudo",
            r"""case "$1" in
    test|cmp) exec "$@" ;;
    env) shift; exec env "$@" ;;
    sbctl) [ "$*" = 'sbctl setup --print-state --json' ] && printf '{"installed":true}\n' ;;
    python3)
        case "$6" in
            inventory) printf '{}\n' ;;
            verify|enrollment)
                [ -f "$MARKER" ] || exit 97
                printf '%s\t\n' "$6" >> "$CALLS"
                [ "$FAILURE" != "$6" ] ;;
            *) exit 97 ;;
        esac ;;
    *) exit 97 ;;
esac""",
        )
        source = self.render(SCRIPTS / "run_after_13_initramfs.sh.tmpl")
        source = source.replace("/usr/bin/limine", str(self.bin / "limine"))
        source = source.replace("/etc/boot/hooks/post.d/90-limine-enroll-config", str(hook))
        source = source.replace(
            '\nmain "$@"',
            '''
command_exists() { return 0; }
keep_sudo_alive() { return 0; }
get_limine_boot_directory() { echo "$BOOT"; }
get_limine_config_value() {
    if [[ "$1" = ENABLE_ENROLL_LIMINE_CONFIG ]]; then echo "$ENROLL"; else echo no; fi
}
main "$@"''',
        )
        for failure, enrollment in (
            ("rebuild", "no"),
            ("verify", "no"),
            ("", "no"),
            ("enrollment", "yes"),
            ("", "yes"),
        ):
            with self.subTest(failure=failure or "success", enrollment=enrollment):
                self.env.update(FAILURE=failure, ENROLL=enrollment)
                marker.touch()
                self.calls.unlink(missing_ok=True)
                result = self.shell(source)
                self.assertEqual(result.returncode, 1 if failure else 0, result.stderr)
                self.assertEqual(marker.exists(), bool(failure))
                calls = self.logged_calls()
                self.assertIn(["limine-install", "--no-efi-register"], calls)
                self.assertIn(["limine-mkinitcpio"], calls)
                self.assertEqual(["verify"] in calls, failure != "rebuild")
                self.assertEqual(["enrollment"] in calls, enrollment == "yes")
                if enrollment == "yes":
                    self.assertLess(calls.index(["verify"]), calls.index(["enrollment"]))


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
            DISTRO_FAMILY="arch",
            MARKER=str(self.marker),
            ENROLLED=str(self.enrolled),
            BOOT=str(self.boot),
            FAILURE="",
            STATE='{"installed":true,"setup_mode":false,"secure_boot":true}',
            POST_STATE='{"installed":true,"setup_mode":false,"secure_boot":false}',
            KEY_CONFIG=json.dumps({"keys": {"db": {"pubkey": str(self.certificate)}}}),
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
        # Implement only this script's jq queries; unknown queries fail the fixture.
        jq = """import json, sys
args = sys.argv[1:]
query = " ".join(args[-1].split())
data = json.load(sys.stdin)
if query == '(.installed | type) == "boolean" and (.setup_mode | type) == "boolean" and (.secure_boot | type) == "boolean"':
    value = all(type(data.get(key)) is bool for key in ("installed", "setup_mode", "secure_boot"))
elif query == ".setup_mode and .secure_boot":
    value = data["setup_mode"] and data["secure_boot"]
elif query in (".installed", ".setup_mode"):
    value = data[query[1:]]
elif query == '.keys.db.pubkey | select(type == "string" and length > 0)':
    value = data.get("keys", {}).get("db", {}).get("pubkey")
    if not isinstance(value, str) or not value:
        sys.exit(1)
    print(value)
    sys.exit(0)
elif query == "any(.DB[]?; .Raw == $certificate)":
    value = any(item.get("Raw") == args[3] for item in data.get("DB", []))
else:
    raise SystemExit("Unexpected jq query: " + query)
print(json.dumps(value))
sys.exit(0 if value else 1)
"""
        self.stub("jq", f'exec {shlex.quote(sys.executable)} -I -B -c {shlex.quote(jq)} "$@"')
        source = self.render(SCRIPTS / "run_onchange_after_05_secure_boot.sh.tmpl")
        source = source.replace("/etc/", f"{self.etc}/").replace("/sys/", f"{self.directory}/sys/")
        source = source.replace("/usr/share/", f"{self.directory}/share/")
        source = source.replace("/usr/bin/limine", str(self.bin / "limine"))
        source = source.replace("\nupdate_config() {", "\nfixture_update_config() {")
        self.source = source.replace(
            '\nmain "$@"',
            r'''
keep_sudo_alive() { return 0; }
update_config() {
    printf 'update\t%s\t\n' "$2" >> "$CALLS"
    [[ -f "$INITRAMFS_PENDING_FILE" ]] || return 97
    [[ "$FAILURE" != "write-$2" ]] || return 23
    fixture_update_config "$@"
}
main "$@"''',
        )
        self.reset()

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
                result = self.shell(self.source)
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
                result = self.shell(self.source)
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
                result = self.shell(self.source)
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
                result = self.shell(self.source)
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
                result = self.shell(self.source)
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
                result = self.shell(self.source)
                self.assertEqual(result.returncode, 1, result.stderr)
                self.assertIn("Failed to request Secure Boot rebuild", result.stderr)
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
                result = self.shell(self.source)
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
