"""Run with: python3 -B -m unittest discover -s .github/tests -v

Exercise real chezmoi-rendered setup scripts and shared shell functions in temp
homes with redirected XDG directories and fail-closed command stubs. Cover call
ordering, transaction cleanup, resume failures, Limine write/marker safety, and
Yazi idempotency. Template syntax, externals, and tool guards live in test_templates.
No production script is run with extra shell options not present in its shebang
or prologue; extracted function fixtures deliberately have no implicit set -e.
"""

import io
import shlex
import sys
import unittest
from pathlib import Path
from subprocess import TimeoutExpired
from unittest.mock import patch

try:
    import tomllib
except ImportError:  # unittest must still discover non-Yazi tests on Python < 3.11.
    tomllib = None

from script_helpers import CHEZMOI, LIB, PYTHON3, SCRIPTS, ScriptCase


class ScriptTests(ScriptCase):
    def test_verbose_output_is_readable_and_preserves_failure_details(self):
        class OutputFixture(ScriptCase):
            def test_sample_success(self):
                """A duplicate description should not appear in the output."""
                pass

            def test_sample_failure(self):
                with self.subTest(scenario="example"):
                    self.fail("failure detail remains visible")

            @unittest.skip("example missing dependency")
            def test_sample_skip(self):
                pass

        output = io.StringIO()
        suite = unittest.defaultTestLoader.loadTestsFromTestCase(OutputFixture)
        result = unittest.TextTestRunner(stream=output, verbosity=2).run(suite)
        text = output.getvalue()
        self.assertIn("Sample success ... ok", text)
        self.assertNotIn("A duplicate description", text)
        self.assertIn("Sample skip ... skipped 'example missing dependency'", text)
        self.assertIn("Sample failure (scenario='example') ... FAIL", text)
        self.assertIn("Traceback (most recent call last):", text)
        self.assertIn("failure detail remains visible", text)
        self.assertEqual(result.testsRun, 3)
        self.assertEqual(len(result.failures), 1)
        self.assertEqual(len(result.skipped), 1)

    def libraries(self, *names):
        return "".join(f"source {shlex.quote(str(LIB / name))}\n" for name in names)

    def before_main(self, source, fixture):
        entry = '\nmain "$@"'
        self.assertEqual(source.count(entry), 1, "Expected one production entrypoint")
        return source.replace(entry, "\n" + fixture + entry)

    def limine_fixture(self, failure=""):
        self.item.write_bytes(b"timeout: 5\n/Arch\nprotocol: linux\n")
        self.marker = self.directory / "state/chezmoi/initramfs.pending"
        temporary = self.directory / "limine-tmp"
        temporary.mkdir(exist_ok=True)
        self.env.update(
            MARKER=str(self.marker), FAILURE=failure, TMPDIR=str(temporary),
            STAGE_MODE=str(self.directory / "stage-mode"),
        )
        self.stub("limine-entry-tool", "exit 97")  # availability check only
        self.stub(
            "sudo",
            r"""case "$1" in
    test|cmp|grep) exec "$@" ;;
    awk)
        case "$FAILURE" in
            awk_empty) exit 0 ;;
            awk_failure) exit 23 ;;
            generated_empty) command "$@" >/dev/null || exit $?; exit 0 ;;
            truncated) printf 'timeout: 0.5\n'; exit 0 ;;
            partial_entries) printf 'timeout: 0.5\n/Arch\nprotocol: linux\n'; exit 0 ;;
        esac
        exec "$@" ;;
    install)
        [ -f "$MARKER" ] || exit 97
        [ "$2" = -m ] && [ "$3" = 0600 ] && [ "$4" = /dev/null ] && [ "$5" = "$ITEM.new" ] || exit 97
        if [ "$FAILURE" = install ]; then
            echo 'fixture stage creation failed' >&2
            exit 23
        fi
        exec "$@" ;;
    chmod)
        [ "$2" = "--reference=$ITEM" ] && [ "$3" = -- ] && [ "$4" = "$ITEM.new" ] || exit 97
        if [ "$FAILURE" = chmod ]; then
            echo 'fixture permission copy failed' >&2
            exit 23
        fi
        exec "$@" ;;
    tee)
        if [ -f "$ITEM.new" ]; then
            stat -c '%a' -- "$ITEM.new" > "$STAGE_MODE"
        else
            printf 'missing\n' > "$STAGE_MODE"
        fi
        [ -f "$MARKER" ] || exit 97
        [ "$2" = -- ] && [ "$3" = "$ITEM.new" ] || exit 97
        if [ "$FAILURE" = tee ]; then
            printf 'partial stage\n' > "$ITEM.new"
            echo 'fixture tee failed' >&2
            exit 23
        fi
        exec "$@" ;;
    mv)
        [ -f "$MARKER" ] || exit 97
        case "$FAILURE" in
            missing|restore) rm -f "$ITEM" ;;
            empty) : > "$ITEM" ;;
        esac
        case "$FAILURE" in
            mv|missing|empty|restore)
                echo 'fixture rename failed' >&2
                exit 23 ;;
        esac
        shift
        [ "$1" != -- ] || shift
        [ "$2" = "$ITEM" ] || exit 97
        exec mv "$@" ;;
    rm)
        [ "$2" = -f ] && [ "$3" = -- ] && [ "$4" = "$ITEM.new" ] || exit 97
        exec "$@" ;;
    *) exit 97 ;;
esac""",
            log=True,
        )
        function = self.function(
            SCRIPTS / "run_onchange_after_08_theming.sh.tmpl",
            "configure_limine_options",
        ).replace("/boot/limine.conf", str(self.item))
        overrides = {
            "backup": 'create_backup() { LAST_ERROR="fixture backup failed"; return 1; }\n',
            "marker": 'request_initramfs_rebuild() { LAST_ERROR="fixture marker failed"; return 1; }\n',
        }
        return (
            self.libraries("common.sh", "snapboot.sh")
            + self.function(LIB / "common.sh", "restore_backup").replace(
                "restore_backup()", "fixture_restore_backup()", 1
            )
            + "\nrestore_backup() {\n"
            '  printf "%s\\0" restore_backup "$#" "$@" >> "$CALLS"\n'
            '  if [[ "$FAILURE" == restore ]]; then\n'
            '    LAST_ERROR="fixture restore failed"; return 1\n'
            "  fi\n"
            '  fixture_restore_backup "$@"\n'
            "}\n"
            + "LIMINE_OPTIONS=(timeout=0.5)\n"
            + overrides.get(failure, "")
            + function
            + '\nif configure_limine_options; then status=0; else status=$?; fi\nprintf "%s\\n" "$LAST_ERROR" >&2\nexit "$status"'
        )

    def test_limine_cleans_temp_files_on_every_exit_path(self):
        for failure, expected_status in (
            ("", 0),
            ("unchanged", 0),
            ("awk_failure", 1),
            ("awk_empty", 1),
            ("truncated", 1),
            ("backup", 1),
            ("marker", 1),
            ("tee", 1),
            ("mv", 1),
            ("restore", 1),
        ):
            with self.subTest(failure=failure or "success"):
                script = self.limine_fixture(failure)
                self.marker.unlink(missing_ok=True)
                if failure == "unchanged":
                    first = self.shell(script, name="Limine initial write")
                    self.assertEqual(first.returncode, 0, first.stderr)
                    self.marker.unlink()
                result = self.shell(script, name=f"Limine cleanup {failure}")
                self.assertEqual(result.returncode, expected_status, result.stderr)
                self.assertEqual(list((self.directory / "limine-tmp").iterdir()), [])
                if failure in ("backup", "marker", "unchanged"):
                    self.assertFalse(self.marker.exists())
                if failure == "restore":
                    self.assertIn("restore backup failed", result.stderr)

    def test_limine_preserves_existing_return_trap(self):
        script = self.limine_fixture()
        script = script.replace(
            "\nif configure_limine_options;",
            "\ntrap ':' RETURN\noriginal_trap=$(trap -p RETURN)\nif configure_limine_options;",
        ).replace(
            'printf "%s\\n" "$LAST_ERROR" >&2',
            '[[ "$(trap -p RETURN)" == "$original_trap" ]] || exit 98\n'
            'printf "%s\\n" "$LAST_ERROR" >&2',
        )
        result = self.shell(script, name="Limine preserves caller RETURN trap")
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_limine_reports_validation_error_once_via_last_error(self):
        script = self.limine_fixture("truncated")
        result = self.shell(script, name="Limine validation reporting")
        self.assertEqual(result.returncode, 1, result.stderr)
        # The fixture reports LAST_ERROR once, just as main delegates to die.
        self.assertEqual(result.stderr.count("Generated Limine config"), 1)

    def test_limine_queues_before_write_and_skips_unchanged_config(self):
        """Limine: queue rebuilds before changes; skip unchanged config."""
        script = self.limine_fixture()
        result = self.shell(script, name="configure_limine_options")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(self.marker.exists())
        self.assertIn("timeout: 0.5", self.item.read_text())
        self.assertEqual([call[1] for call in self.logged_calls()].count("mv"), 1)
        self.marker.unlink()
        before = self.item.stat().st_mtime_ns
        result = self.shell(script, name="configure_limine_options (unchanged)")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.marker.exists())
        self.assertEqual(self.item.stat().st_mtime_ns, before)
        self.assertEqual([call[1] for call in self.logged_calls()].count("mv"), 1)

    def test_limine_refreshes_stale_backup_before_successful_write(self):
        script = self.limine_fixture()
        original = self.item.read_bytes()
        backup = self.item.with_suffix(".bak")
        stale = b"timeout: 99\n/Stale\n"
        backup.write_bytes(stale)
        result = self.shell(script, name="Limine refresh stale backup")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(backup.read_bytes(), original)
        self.assertNotEqual(backup.read_bytes(), stale)
        self.assertIn(b"timeout: 0.5\n", self.item.read_bytes())

    def test_limine_restores_only_missing_or_empty_config_after_write_failure(self):
        for failure in ("missing", "empty", "restore"):
            with self.subTest(failure=failure):
                script = self.limine_fixture(failure)
                self.calls.unlink(missing_ok=True)
                original = self.item.read_bytes()
                backup = self.item.with_suffix(".bak")
                backup.write_bytes(b"timeout: 99\n/Stale\n")
                result = self.shell(script, name=f"Limine recovery {failure}")
                self.assertEqual(result.returncode, 1, result.stderr)
                self.assertEqual(backup.read_bytes(), original)
                calls = self.logged_calls()
                self.assertEqual(
                    [call for call in calls if call[0] == "restore_backup"],
                    [["restore_backup", str(self.item)]],
                )
                self.assertIn(
                    ["sudo", "rm", "-f", "--", str(self.item) + ".new"], calls
                )
                self.assertFalse(self.item.with_suffix(".new").exists())
                self.assertTrue(self.marker.exists())
                if failure == "restore":
                    self.assertFalse(self.item.exists())
                    self.assertIn(
                        "Failed to write Limine options and restore backup failed: "
                        "fixture restore failed",
                        result.stderr,
                    )
                else:
                    self.assertEqual(self.item.read_bytes(), original)
                    self.assertIn("backup restored", result.stderr)

    def test_limine_backup_failure_prevents_marker_and_writes(self):
        script = self.limine_fixture("backup")
        original = self.item.read_bytes()
        result = self.shell(script, name="Limine backup failure")
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn(
            "Failed to backup limine config: fixture backup failed", result.stderr
        )
        self.assertEqual(self.item.read_bytes(), original)
        self.assertFalse(self.marker.exists())
        self.assertFalse(any(call[1] in ("tee", "mv") for call in self.logged_calls()))
        self.assertEqual(list((self.directory / "limine-tmp").iterdir()), [])

    def test_limine_stage_is_private_and_preserves_original_permissions(self):
        for mode, leftover in ((0o600, False), (0o600, True), (0o640, False), (0o644, False)):
            with self.subTest(mode=oct(mode), leftover=leftover):
                script = self.limine_fixture()
                self.item.chmod(mode)
                # A leftover permissive stage must also be reset before writing.
                stage = self.item.with_suffix(".new")
                if leftover:
                    stage.write_text("old stage")
                    stage.chmod(0o666)
                result = self.shell("umask 022\n" + script, name="Limine file modes")
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual((self.directory / "stage-mode").read_text().strip(), "600")
                self.assertEqual(self.item.stat().st_mode & 0o7777, mode)
                self.assertIn(b"timeout: 0.5\n", self.item.read_bytes())
                self.assertFalse(stage.exists())

    def test_limine_permission_failures_preserve_original_and_clean_stage(self):
        for failure in ("install", "chmod"):
            with self.subTest(failure=failure):
                script = self.limine_fixture(failure)
                self.calls.unlink(missing_ok=True)
                self.item.chmod(0o600)
                original = self.item.read_bytes()
                result = self.shell("umask 022\n" + script, name=f"Limine {failure}")
                self.assertEqual(result.returncode, 1, result.stderr)
                self.assertEqual(self.item.read_bytes(), original)
                self.assertEqual(self.item.stat().st_mode & 0o7777, 0o600)
                self.assertTrue(self.marker.exists())
                self.assertIn("Failed to write Limine options", result.stderr)
                calls = self.logged_calls()
                self.assertFalse(any(call[1] == "mv" for call in calls))
                self.assertFalse(any(call[0] == "restore_backup" for call in calls))
                self.assertIn(["sudo", "rm", "-f", "--", str(self.item) + ".new"], calls)
                self.assertFalse(self.item.with_suffix(".new").exists())
                self.assertEqual(list((self.directory / "limine-tmp").iterdir()), [])

    def test_limine_stages_beside_config_before_atomic_rename(self):
        script = self.limine_fixture()
        result = self.shell(script, name="Limine staged write")
        self.assertEqual(result.returncode, 0, result.stderr)
        writes = [
            call for call in self.logged_calls()
            if call[1] in ("install", "tee", "chmod", "mv")
        ]
        self.assertEqual(
            writes,
            [
                ["sudo", "install", "-m", "0600", "/dev/null", str(self.item) + ".new"],
                ["sudo", "tee", "--", str(self.item) + ".new"],
                ["sudo", "chmod", "--reference=" + str(self.item), "--", str(self.item) + ".new"],
                ["sudo", "mv", "--", str(self.item) + ".new", str(self.item)],
            ],
        )
        self.assertEqual(
            self.item.read_bytes(),
            b"timeout: 0.5\n\n\n\n/Arch\nprotocol: linux\n",
        )
        self.assertFalse(self.item.with_suffix(".new").exists())

    def test_limine_staged_write_failures_preserve_original_and_retain_marker(self):
        """Keep the queued rebuild on both failed staging and failed rename."""
        for failure in ("tee", "mv"):
            with self.subTest(failure=failure):
                script = self.limine_fixture(failure)
                self.calls.unlink(missing_ok=True)
                original = self.item.read_bytes()
                backup = self.item.with_suffix(".bak")
                stale = b"timeout: 99\n/Stale\n"
                backup.write_bytes(stale)
                result = self.shell(script, name=f"Limine {failure} failure")
                self.assertEqual(result.returncode, 1, result.stderr)
                self.assertEqual(self.item.read_bytes(), original)
                self.assertTrue(self.marker.exists())
                self.assertIn("Failed to write Limine options", result.stderr)
                self.assertNotIn("backup restored", result.stderr)
                self.assertEqual(backup.read_bytes(), original)
                self.assertNotEqual(backup.read_bytes(), stale)
                self.assertFalse(
                    any(call[0] == "restore_backup" for call in self.logged_calls())
                )
                self.assertIn(
                    "fixture tee failed"
                    if failure == "tee"
                    else "fixture rename failed",
                    result.stderr,
                )
                calls = self.logged_calls()
                self.assertIn(
                    ["sudo", "rm", "-f", "--", str(self.item) + ".new"], calls
                )
                if failure == "tee":
                    self.assertFalse(any(call[1] == "mv" for call in calls))
                self.assertFalse(self.item.with_suffix(".new").exists())

    def test_limine_rejects_empty_or_truncated_output(self):
        """Rejected generated config must preserve bytes and any pending rebuild."""
        for failure in ("awk_empty", "generated_empty", "truncated"):
            for pending in (False, True):
                with self.subTest(failure=failure, pending=pending):
                    script = self.limine_fixture(failure)
                    self.marker.unlink(missing_ok=True)
                    if pending:
                        self.marker.parent.mkdir(parents=True, exist_ok=True)
                        self.marker.touch()
                    original = self.item.read_bytes()
                    result = self.shell(script, name=f"Limine {failure}")
                    # A pre-write validation failure must not clear an existing marker
                    # or request a rebuild for bytes that were never committed.
                    violations = []
                    if self.item.read_bytes() != original:
                        violations.append(
                            "empty/truncated output replaced the original boot config"
                        )
                    if result.returncode == 0:
                        violations.append("invalid output was accepted with exit 0")
                    if self.marker.exists() != pending:
                        violations.append(
                            "rejected output changed the pending-marker state"
                        )
                    self.assertFalse(
                        violations, "Unsafe Limine write: " + "; ".join(violations)
                    )

    def test_limine_rejects_partial_entry_loss(self):
        script = self.limine_fixture("partial_entries")
        self.item.write_bytes(
            b"timeout: 5\n/Arch\nprotocol: linux\n"
            b"/Fallback\nprotocol: linux\n/Recovery\nprotocol: linux\n"
        )
        original = self.item.read_bytes()
        result = self.shell(script, name="Limine three entries in, one out")
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn("Generated Limine config", result.stderr)
        self.assertEqual(self.item.read_bytes(), original)
        self.assertFalse(self.marker.exists())
        self.assertFalse(any(call[1] == "mv" for call in self.logged_calls()))

    def test_limine_rejects_original_without_entries(self):
        """No entries means no verifiable boot config: fail closed, never rewrite."""
        script = self.limine_fixture()
        self.item.write_bytes(b"timeout: 5\n# no boot entries\n")
        original = self.item.read_bytes()
        result = self.shell(
            "set -euo pipefail\n" + script,
            name="Limine original with zero entries",
        )
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn("Generated Limine config", result.stderr)
        self.assertEqual(self.item.read_bytes(), original)
        self.assertFalse(self.marker.exists())

    def test_limine_awk_failure_preserves_config_and_marker(self):
        for pending in (False, True):
            with self.subTest(pending=pending):
                script = self.limine_fixture("awk_failure")
                self.marker.unlink(missing_ok=True)
                if pending:
                    self.marker.parent.mkdir(parents=True, exist_ok=True)
                    self.marker.touch()
                original = self.item.read_bytes()
                result = self.shell(script, name="Limine awk failure")
                self.assertEqual(result.returncode, 1, result.stderr)
                self.assertIn("Failed to transform Limine config", result.stderr)
                self.assertEqual(self.item.read_bytes(), original)
                self.assertEqual(
                    self.marker.exists(),
                    pending,
                    "Transform failure must leave the marker unchanged",
                )

    def test_limine_mv_failure_preserves_config_and_retains_marker(self):
        script = self.limine_fixture("mv")
        original = self.item.read_bytes()
        result = self.shell(script, name="Limine mv failure")
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertEqual(self.item.read_bytes(), original)
        self.assertTrue(
            self.marker.exists(),
            "Queued rebuild must survive a failed commit for retry",
        )
        self.assertIn("Failed to write Limine options", result.stderr)
        self.assertNotIn("backup restored", result.stderr)
        self.assertFalse(
            any(call[0] == "restore_backup" for call in self.logged_calls())
        )

    def test_limine_missing_config_does_not_create_it_or_clear_marker(self):
        for pending in (False, True):
            with self.subTest(pending=pending):
                script = self.limine_fixture()
                self.item.unlink()
                self.marker.unlink(missing_ok=True)
                if pending:
                    self.marker.parent.mkdir(parents=True, exist_ok=True)
                    self.marker.touch()
                result = self.shell(script, name="Limine missing config")
                self.assertEqual(result.returncode, 2, result.stderr)
                self.assertIn("Limine config not found", result.stderr)
                self.assertFalse(
                    self.item.exists(), "Missing boot config must not be created"
                )
                self.assertEqual(
                    self.marker.exists(),
                    pending,
                    "Missing config must leave the marker unchanged",
                )

    @unittest.skipUnless(
        CHEZMOI, "chezmoi is required to render the hibernation transaction"
    )
    def test_btrfs_creation_mounts_the_top_level(self):
        """Btrfs: mount before create; clean up the mount even when create fails."""
        self.stub(
            "sudo",
            r"""case "$*" in
    'btrfs subvolume list /') exit 0 ;;
    'mount -o subvolid=5 /dev/fixture '*) exit 0 ;;
    'btrfs subvolume create '*) exit 23 ;;
    'umount '*) exit 0 ;;
    *) exit 97 ;;
esac""",
            log=True,
        )
        self.stub("mountpoint", "exit 0", log=True)
        self.stub("limine", "exit 97")
        path = SCRIPTS / "run_onchange_after_03_hibernation.sh.tmpl"
        source = self.render(path).replace("/usr/bin/limine", str(self.bin / "limine"))
        # Bypass platform/privilege prerequisites, not the transaction or its traps.
        source = self.before_main(
            source,
            """command_exists() { return 0; }
check_btrfs() { return 0; }
is_laptop() { return 0; }
keep_sudo_alive() { return 0; }
validate_mkinitcpio_dropins() { return 0; }
get_swap_path() { printf ''; }
get_btrfs_root_device() { echo /dev/fixture; }
""",
        )
        result = self.shell(source, name=path.name)
        # Production intentionally turns swap creation failures into a graceful skip.
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Failed to create btrfs swap subvolume", result.stderr)
        calls = self.logged_calls()
        self.assertEqual(calls[0], ["sudo", "btrfs", "subvolume", "list", "/"])
        mount = calls[1]
        self.assertEqual(
            mount[:5], ["sudo", "mount", "-o", "subvolid=5", "/dev/fixture"]
        )
        target = mount[5]
        self.assertEqual(
            calls[2:],
            [
                ["sudo", "btrfs", "subvolume", "create", target + "/@swap"],
                ["mountpoint", "-q", target],
                ["sudo", "umount", target],
            ],
        )
        self.assertFalse(
            Path(target).exists(),
            "Temporary mount directory leaked",
        )
        # Keep the original helper's claim: creation failure itself is nonzero.
        self.calls.unlink()
        result = self.shell(
            self.libraries("hibernation.sh")
            + "get_btrfs_root_device() { echo /dev/fixture; }\ncreate_btrfs_swap",
            name="create_btrfs_swap",
        )
        self.assertNotEqual(result.returncode, 0)

    def test_resume_uses_the_swapfiles_filesystem(self):
        """Hibernation: exact swapfile UUID/offset arguments and early failures."""
        function = self.function(LIB / "hibernation.sh", "setup_hibernation").replace(
            "/etc/limine-entry-tool.d/01-default.conf", str(self.item)
        )
        self.stub("update-limine", "exit 0", log=True)
        self.stub("write-dropin", "exit 0", log=True)
        script = (
            self.libraries("common.sh", "hibernation.sh")
            + """
get_swap_path() { echo "$ITEM"; }
update_limine_cmdline() { update-limine "$@"; }
write_mkinitcpio_dropin() { write-dropin "$@"; }
"""
            + function
            + '\nsetup_hibernation\nstatus=$?\necho "$LAST_ERROR" >&2\nexit "$status"'
        )
        for failure in (None, "findmnt", "map-swapfile"):
            with self.subTest(failure=failure):
                self.calls.unlink(missing_ok=True)
                self.stub(
                    "findmnt",
                    "exit 23" if failure == "findmnt" else "echo swap-uuid",
                    log=True,
                )
                self.stub(
                    "sudo",
                    "exit 23" if failure == "map-swapfile" else "echo 123",
                    log=True,
                )
                result = self.shell(script, name=f"setup_hibernation ({failure})")
                expected = [["findmnt", "-n", "-o", "UUID", "--target", str(self.item)]]
                if failure != "findmnt":
                    expected.append(
                        [
                            "sudo",
                            "btrfs",
                            "inspect-internal",
                            "map-swapfile",
                            "-r",
                            str(self.item),
                        ]
                    )
                if failure:
                    self.assertEqual(result.returncode, 1, result.stderr)
                    self.assertIn(
                        "Failed to get "
                        + ("filesystem UUID" if failure == "findmnt" else "offset"),
                        result.stderr,
                    )
                    self.assertEqual(
                        self.logged_calls(),
                        expected,
                        "Failure must stop before writing resume config",
                    )
                else:
                    self.assertEqual(result.returncode, 0, result.stderr)
                    calls = self.logged_calls()
                    self.assertEqual(
                        calls[:3],
                        expected
                        + [
                            [
                                "update-limine",
                                "50-hibernation.conf",
                                "--append",
                                "hibernate.compressor=lz4",
                                "resume=UUID=swap-uuid",
                                "resume_offset=123",
                            ]
                        ],
                    )
                    self.assertEqual(len(calls), 4)
                    self.assertEqual(calls[3][:2], ["write-dropin", "hibernation.conf"])

    def yazi_fixture(self, scenario):
        required = ["ahkohd/eza-preview", "yazi-rs/plugins:full-border"]
        registered = {
            "missing_file": [],
            "empty_deps": [],
            "unrelated_deps": [],
            "partial": required[:1],
            "all_registered": required,
        }[scenario]
        config = self.directory / "custom-yazi"
        config.mkdir(exist_ok=True)
        self.package = config / "package.toml"
        if scenario == "missing_file":
            self.package.unlink(missing_ok=True)
        else:
            entries = [] if scenario == "empty_deps" else ["example/keep", *registered]
            self.package.write_text(
                "[plugin]\ndeps = [\n"
                + "".join(
                    f'{{ use = "{plugin}", rev = "keep-revision" }},\n'
                    for plugin in entries
                )
                + ']\n[flavor]\ndeps = [{ use = "example/theme", rev = "keep-theme" }]\n'
            )
        self.calls.unlink(missing_ok=True)
        self.env.update(YAZI_CONFIG_HOME=str(config), PACKAGE_FILE=str(self.package))
        self.stub(
            "ya",
            """exec python3 - "$@" <<'PY'
import json, os, sys, tomllib
from pathlib import Path
path = Path(os.environ["PACKAGE_FILE"])

if os.environ.get("FAIL_YA") == sys.argv[2]:
    sys.exit(23)
if sys.argv[1:3] == ["pkg", "add"]:
    content = path.read_text() if path.exists() else "[plugin]" + chr(10) + "deps = []" + chr(10)
    registered = {dep["use"] for dep in tomllib.loads(content)["plugin"]["deps"]}
    for plugin in sys.argv[3:]:
        assert plugin not in registered, "Package already exists"
        content = content.replace("deps = [", 'deps = [\\n{ use = ' + json.dumps(plugin) + ', rev = "added" },', 1)
    path.write_text(content)
else:
    assert sys.argv[1:] == ["pkg", "install"]
PY""",
            log=True,
        )
        return self.render(SCRIPTS / "run_onchange_after_11_yazi.sh.tmpl"), registered

    @unittest.skipUnless(CHEZMOI, "chezmoi is required to render Yazi setup")
    @unittest.skipUnless(
        sys.version_info >= (3, 11), "Yazi fixtures require Python >= 3.11 (tomllib)"
    )
    @unittest.skipUnless(PYTHON3, "python3 is required by the ya fixture stub")
    def test_yazi_adds_only_missing_plugins_and_succeeds_twice(self):
        """Yazi: repeat setup safely and preserve existing plugins."""
        required = ["ahkohd/eza-preview", "yazi-rs/plugins:full-border"]
        for scenario in (
            "missing_file",
            "empty_deps",
            "unrelated_deps",
            "partial",
            "all_registered",
        ):
            with self.subTest(scenario=scenario):
                source, registered = self.yazi_fixture(scenario)
                for attempt in (1, 2):
                    result = self.shell(
                        source, name=f"Yazi {scenario} attempt {attempt}"
                    )
                    self.assertEqual(result.returncode, 0, result.stderr)
                calls = self.logged_calls()
                missing = [p for p in required if p not in registered]
                expected = [["ya", "pkg", "add", *missing]] if missing else []
                self.assertEqual(calls, expected + [["ya", "pkg", "install"]] * 2)
                data = tomllib.loads(self.package.read_text())
                self.assertEqual(
                    {p["use"] for p in data["plugin"]["deps"]} & set(required),
                    set(required),
                )
                if scenario not in ("missing_file", "empty_deps"):
                    self.assertIn(
                        {"use": "example/keep", "rev": "keep-revision"},
                        data["plugin"]["deps"],
                    )
                    self.assertEqual(
                        data["flavor"]["deps"],
                        [{"use": "example/theme", "rev": "keep-theme"}],
                    )

    @unittest.skipUnless(CHEZMOI, "chezmoi is required to render Yazi setup")
    @unittest.skipUnless(
        sys.version_info >= (3, 11), "Yazi fixtures require Python >= 3.11 (tomllib)"
    )
    @unittest.skipUnless(PYTHON3, "python3 is required by the ya fixture stub")
    def test_yazi_package_errors_are_not_suppressed(self):
        """Yazi: report plugin registration and installation failures."""
        for failure in ("add", "install"):
            with self.subTest(command=failure):
                source, _ = self.yazi_fixture("empty_deps")
                self.env["FAIL_YA"] = failure
                result = self.shell(source, name=f"Yazi failed {failure}")
                self.assertEqual(result.returncode, 1, result.stderr)
                self.assertNotIn("INFO: Installed Yazi plugins", result.stderr)
                calls = self.logged_calls()
                self.assertEqual(
                    [call[2] for call in calls],
                    ["add"] if failure == "add" else ["add", "install"],
                )

    @unittest.skipUnless(CHEZMOI, "chezmoi is required to render services setup")
    def test_service_failures_propagate(self):
        """Services: real main/die stop at the failing systemctl step."""
        path = SCRIPTS / "run_onchange_after_14_services.sh.tmpl"
        rendered = self.render(path)
        # Inject only the privilege prerequisite fixture; retain the complete
        # rendered script, its production options, entrypoint, services, and die.
        prerequisite = "\nif ! keep_sudo_alive; then"
        self.assertEqual(rendered.count(prerequisite), 1)
        source = rendered.replace(
            prerequisite, "\nkeep_sudo_alive() { return 0; }\n" + prerequisite
        )
        self.stub("figlet", "exit 0")
        for failure in ("show", "unmask", "enable"):
            with self.subTest(command=failure):
                self.calls.unlink(missing_ok=True)
                self.stub(
                    "systemctl",
                    f'[ "$2" != {failure} ] || exit 23\n[ "$2" != show ] || echo loaded\nexit 0',
                    log=True,
                )
                self.stub("mise", "exit 97", log=True)
                self.stub("updatedb", "exit 97", log=True)
                result = self.shell(source, name=f"{path.name} failed {failure}")
                self.assertEqual(
                    result.returncode, 1, result.stderr
                )  # common.sh die default
                self.assertIn("Failed to apply packaged user services", result.stderr)
                service = "gnome-keyring-daemon.socket"
                expected = [
                    [
                        "systemctl",
                        "--user",
                        "show",
                        "--property=LoadState",
                        "--value",
                        "--",
                        service,
                    ]
                ]
                if failure != "show":
                    expected.append(["systemctl", "--user", "unmask", "--", service])
                if failure == "enable":
                    expected.append(
                        ["systemctl", "--user", "enable", "--now", "--", service]
                    )
                self.assertEqual(
                    self.logged_calls(),
                    expected,
                    "A later step ran after systemctl failed",
                )

    def test_unavailable_services_are_skipped(self):
        """Services: inspect optional units, but do not unmask/enable/start them."""
        self.stub("systemctl", '[ "$2" = show ] || exit 97\necho not-found', log=True)
        function = self.function(
            SCRIPTS / "run_onchange_after_14_services.sh.tmpl",
            "converge_packaged_user_services",
        )
        result = self.shell(
            self.libraries("common.sh")
            + "USER_SERVICES=(fixture.service)\n"
            + function
            + "\nconverge_packaged_user_services",
            name="converge_packaged_user_services",
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            self.logged_calls(),
            [
                [
                    "systemctl",
                    "--user",
                    "show",
                    "--property=LoadState",
                    "--value",
                    "--",
                    "fixture.service",
                ]
            ],
        )

    def test_stub_log_preserves_arguments_and_order(self):
        self.stub("fixture-command", "exit 0", log=True)
        result = self.shell(
            "fixture-command '' 'two words'\nfixture-command", name="stub log fixture"
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            self.logged_calls(),
            [["fixture-command", "", "two words"], ["fixture-command"]],
        )

    def test_shell_respects_shebang_and_does_not_add_errexit(self):
        # Scripts without set -e intentionally continue after a failed command.
        result = self.shell(
            "#!/bin/sh\nfalse\nprintf reached", name="no errexit fixture"
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "reached")
        self.stub("fixture-interpreter", 'printf "selected interpreter"')
        result = self.shell(
            f"#!{self.bin / 'fixture-interpreter'}\nexit 97", name="shebang fixture"
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "selected interpreter")

    def test_shell_timeout_names_the_script(self):
        with patch(
            "script_helpers.subprocess.run", side_effect=TimeoutExpired("fixture", 15)
        ):
            with self.assertRaisesRegex(
                AssertionError, "fixture-timeout.sh timed out after 15s"
            ):
                self.shell("true", name="fixture-timeout.sh")

    def test_function_extraction_supports_shell_declaration_forms(self):
        for declaration in (
            "fixture() {",
            "fixture()\n{",
            "function fixture {",
            "function fixture\n{",
            "function fixture() {",
        ):
            with self.subTest(declaration=declaration):
                source = declaration + "\n  :\n}\nother() {\n  false\n}\n"
                self.assertEqual(
                    self.function(self.item, "fixture", source=source),
                    source.split("\nother")[0],
                )

    def test_function_extraction_names_missing_function_and_file(self):
        with self.assertRaisesRegex(
            AssertionError, rf"{self.item}: function 'missing' not found"
        ):
            self.function(self.item, "missing")
