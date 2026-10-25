"""Before hooks must stop when essential package installation fails."""

# JSON fixture assertions and runpy inspect dynamic application objects.
# pyright: reportAny=false

import json
import os
import runpy
import shutil
import subprocess
import tomllib
from pathlib import Path
from types import SimpleNamespace
from typing import override
from unittest.mock import MagicMock, patch

import pytest
from helpers import CHEZMOI, ROOT, SCRIPTS, ScriptCase


class PackageTests(ScriptCase):
    @override
    def setUp(self) -> None:
        super().setUp()
        self.packages = ROOT / "home/.chezmoitemplates/packages.py"
        self.env.update(
            NOCONFIRM="1",
            OFFLINE="1",
            PACKAGES="linux 6.18-1\nlinux-headers 6.18-1",
            GPU="Intel Corporation [8086:1234]",
            DRIVER_VERSION="615.78.08",
            MISE_STATUS="0",
            UPGRADE_STATUS="0",
        )
        self.stub("id", "echo 1000")
        self.stub("yay", "exit 97")
        self.stub("pacman-conf", "echo chaotic-aur")
        self.stub(
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
        self.stub(
            "sudo",
            r'''[ "$*" = 'pacman -Syu --noconfirm' ] || exit 97
exit "$UPGRADE_STATUS"''',
            log=True,
        )
        self.stub("hostnamectl", "echo laptop")
        self.stub("lspci", 'printf "01:00.0 VGA compatible controller [0300]: %s\n" "$GPU"')
        self.stub("limine", "exit 97")
        self.stub("mkinitcpio", "exit 97")
        self.stub(
            "modinfo",
            r"""case "$*" in
    '-k 6.18-fixture -F vermagic nvidia') echo '6.18-fixture SMP' ;;
    '-k 6.18-fixture -F version nvidia') echo "$DRIVER_VERSION" ;;
    *) exit 97 ;;
esac""",
        )
        self.stub(
            "mise",
            r'''/usr/bin/python3 -B - <<'CHECK'
import json, os
from pathlib import Path
assert Path(os.environ['GNUPGHOME']).is_dir()
assert Path(os.environ['GNUPGHOME']).stat().st_mode & 0o777 == 0o700
assert not os.environ.get('MISE_ENV')
assert not os.environ.get('MISE_CONFIG_FILE')
assert os.environ['OFFLINE'] == '1' and os.environ['NOCONFIRM'] == '1'
Path(os.environ['HOME'], 'observed.json').write_text(json.dumps({
    key: os.environ.get(key) for key in ('XDG_CONFIG_HOME', 'XDG_DATA_HOME', 'XDG_STATE_HOME',
                                       'GOPATH', 'CARGO_HOME', 'GNUPGHOME')}))
CHECK
[ "$?" = 0 ] || exit 98
exit "$MISE_STATUS"''',
            log=True,
        )

    def apply_packages(
        self, *, personal: bool = False, distro: str = "arch"
    ) -> subprocess.CompletedProcess[str]:
        command = [
            "/usr/bin/python3",
            "-B",
            str(self.packages),
            "--root",
            str(ROOT),
            "--distro",
            distro,
        ]
        if personal:
            command.append("--personal")
        return self.run_process(command, name="package orchestration")

    def test_fresh_kvm_nonpersonal_packages_need_no_vulkan_provider_or_hardware_probe(self) -> None:
        for name in ("lspci", "hostnamectl", "rbw", "systemctl", "sbctl"):
            self.stub(name, "exit 97", log=True)
        self.env.update(MISE_ENV="personal", MISE_CONFIG_FILE="/unrelated/config.toml")
        result = self.apply_packages()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            [call for call in self.logged_calls() if call[0] == "mise"],
            [["mise", "--env", "packages", "bootstrap", "packages", "apply", "--yes"]],
        )
        self.assertTrue(all(call[0] in ("sudo", "mise") for call in self.logged_calls()))
        observed = json.loads((self.directory / "observed.json").read_text())
        self.assertEqual(observed["GOPATH"], str(self.directory / "data/go"))
        declarations = tomllib.loads((ROOT / "mise/conf.d/packages.toml").read_text())["bootstrap"][
            "packages"
        ]
        # Zed requires a Vulkan driver; it must not let baseline resolution pull NVIDIA.
        self.assertEqual(declarations["pacman:zed"]["env"], "personal")

    def test_chaotic_trust_upgrade_and_mise_helper_are_ordered_and_repeatable(self) -> None:
        (self.bin / "yay").unlink()
        self.stub(
            "pacman",
            r"""case "$*" in
    '-Q chaotic-keyring chaotic-mirrorlist') test -f "$HOME/trust-installed" ;;
    *) exit 97 ;;
esac""",
        )
        self.stub(
            "pacman-conf", 'echo core; if test -f "$HOME/repo-enabled"; then echo chaotic-aur; fi'
        )
        self.stub(
            "sudo",
            r"""test -d "$GNUPGHOME" || exit 98
case "$*" in
    'pacman-key --list-keys 3056513887B78AEB') exit 1 ;;
    'pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com'|'pacman-key --lsign-key 3056513887B78AEB') exit 0 ;;
    'pacman -U --needed --noconfirm '*) touch "$HOME/trust-installed" ;;
    'tee -a /etc/pacman.conf') cat >> "$HOME/pacman.conf"; touch "$HOME/repo-enabled" ;;
    'pacman -Syu --noconfirm') test -f "$HOME/trust-installed" && test -f "$HOME/repo-enabled" ;;
    *) exit 97 ;;
esac""",
            log=True,
        )
        self.stub(
            "mise",
            r"""if [ "$*" = '--env aur-helper bootstrap packages apply --yes' ]; then
    printf '#!/bin/sh\nexit 97\n' > "$HOME/bin/yay"
    chmod 755 "$HOME/bin/yay"
elif [ "$*" != '--env packages bootstrap packages apply --yes' ]; then
    exit 97
fi""",
            log=True,
        )
        for _ in range(2):
            result = self.apply_packages()
            self.assertEqual(result.returncode, 0, result.stderr)
        calls = self.logged_calls()
        self.assertEqual(
            [call[1] for call in calls[:6]],
            ["pacman-key", "pacman-key", "pacman-key", "pacman", "tee", "pacman"],
        )
        self.assertEqual(
            [call[2] for call in calls if call[0] == "mise"], ["aur-helper", "packages", "packages"]
        )
        self.assertEqual((self.directory / "pacman.conf").read_text().count("[chaotic-aur]"), 1)
        self.assertTrue((self.directory / "state/chezmoi/chaotic-aur-updated").is_file())

    def test_personal_package_groups_and_legacy_provider_order(self) -> None:
        for gpu, version, family, module in (
            (
                "NVIDIA Corporation GP106 [10de:1234]",
                "580.119.02",
                "nvidia-legacy",
                "nvidia-legacy-dkms",
            ),
            ("NVIDIA Corporation GA106 [10de:1234]", "615.78.08", "nvidia-current", "nvidia-open"),
        ):
            with self.subTest(family=family):
                self.calls.unlink(missing_ok=True)
                self.env.update(GPU=gpu, DRIVER_VERSION=version)
                result = self.apply_packages(personal=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                calls = [call for call in self.logged_calls() if call[0] == "mise"]
                groups = calls[-1][2].split(",")
                for group in (
                    "packages",
                    "personal",
                    "driver-utils",
                    "laptop",
                    "limine-mkinitcpio",
                    "snapper",
                    family,
                    module,
                ):
                    self.assertIn(group, groups)
                if family == "nvidia-legacy":
                    self.assertEqual(calls[0][1:3], ["--env", "nvidia-legacy-utils"])

    def test_derivatives_leave_nvidia_modules_to_the_distribution(self) -> None:
        self.env["GPU"] = "NVIDIA Corporation GA106 [10de:1234]"
        for distro in ("cachyos", "garuda"):
            with self.subTest(distro=distro):
                self.calls.unlink(missing_ok=True)
                result = self.apply_packages(personal=True, distro=distro)
                self.assertEqual(result.returncode, 0, result.stderr)
                groups = [call for call in self.logged_calls() if call[0] == "mise"][-1][2].split(
                    ","
                )
                self.assertIn("nvidia-current", groups)
                self.assertNotIn("nvidia-open", groups)

    def test_conflicting_drivers_or_kernel_headers_stop_before_mise(self) -> None:
        self.env["GPU"] = "NVIDIA Corporation GA106 [10de:1234]"
        for packages in ("linux 6.18-1\nlinux-headers 6.17-1", "nvidia-580xx-utils 580.119.02-1"):
            with self.subTest(packages=packages):
                self.calls.unlink(missing_ok=True)
                self.env["PACKAGES"] = packages
                result = self.apply_packages(personal=True)
                self.assertNotEqual(result.returncode, 0)
                self.assertFalse(any(call[0] == "mise" for call in self.logged_calls()))

    def test_missing_nvidia_module_fails_after_installation(self) -> None:
        self.env["GPU"] = "NVIDIA Corporation GA106 [10de:1234]"
        self.stub("modinfo", "exit 23")
        result = self.apply_packages(personal=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("6.18-fixture", result.stderr)
        self.assertTrue(any(call[0] == "mise" for call in self.logged_calls()))

    def test_xdg_reapplication_preserves_custom_paths_and_existing_maven_settings(self) -> None:
        self.env.update(
            GNUPGHOME=str(self.directory / "private-gnupg"),
            CARGO_HOME=str(self.directory / "custom-cargo"),
        )
        settings = self.directory / "config/maven/settings.xml"
        settings.parent.mkdir(parents=True)
        settings.write_text("existing-private-settings")
        before = settings.stat().st_mtime_ns
        for _ in range(2):
            result = self.apply_packages()
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(settings.read_text(), "existing-private-settings")
            self.assertEqual(settings.stat().st_mtime_ns, before)
            self.assertNotIn("existing-private-settings", result.stderr)
        observed = json.loads((self.directory / "observed.json").read_text())
        self.assertEqual(observed["CARGO_HOME"], self.env["CARGO_HOME"])
        self.assertEqual(observed["GNUPGHOME"], self.env["GNUPGHOME"])
        self.assertEqual(
            sum(call == ["sudo", "pacman", "-Syu", "--noconfirm"] for call in self.logged_calls()),
            1,
        )

    def test_failed_initial_upgrade_does_not_record_success_or_run_mise(self) -> None:
        self.env["UPGRADE_STATUS"] = "23"
        result = self.apply_packages()
        self.assertEqual(result.returncode, 23, result.stderr)
        self.assertFalse((self.directory / "state/chezmoi/chaotic-aur-updated").exists())
        self.assertFalse(any(call[0] == "mise" for call in self.logged_calls()))

    def test_chezmoi_retries_failures_and_tracks_only_package_dependencies(self) -> None:
        if not CHEZMOI:
            self.skipTest("chezmoi is required for package change detection")
        repository = self.directory / "source"
        templates = repository / "home/.chezmoitemplates"
        scripts = repository / "home/.chezmoiscripts/linux"
        templates.mkdir(parents=True)
        scripts.mkdir(parents=True)
        shutil.copytree(ROOT / "mise", repository / "mise")
        for name in ("bootstrap.py", "packages.py"):
            shutil.copy(ROOT / "home/.chezmoitemplates" / name, templates / name)
        launcher = "run_onchange_before_02_packages.sh.tmpl"
        shutil.copy(SCRIPTS / launcher, scripts / launcher)
        config = self.directory / "chezmoi.json"
        config.write_text(json.dumps({"data": {"personal": False, "distroFamily": "arch"}}))
        command = [
            CHEZMOI,
            "--config",
            str(config),
            "--source",
            str(repository / "home"),
            "--working-tree",
            str(repository),
            "--destination",
            str(self.directory / "target"),
            "--no-tty",
            "apply",
        ]
        self.env["MISE_STATUS"] = "23"
        failed = self.run_process(command, name="failed package apply")
        self.assertNotEqual(failed.returncode, 0)
        self.env["MISE_STATUS"] = "0"
        for target, expected in (
            (None, 2),
            (None, 2),
            (repository / "mise/conf.d/services.toml", 2),
            (repository / "mise/conf.d/packages.toml", 3),
            (templates / "bootstrap.py", 3),
            (templates / "packages.py", 4),
        ):
            with self.subTest(target=target, expected=expected):
                if target:
                    with target.open("a") as stream:
                        stream.write("\n# changed\n")
                result = self.run_process(command, name="package change detection")
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(sum(call[0] == "mise" for call in self.logged_calls()), expected)


class PythonApplicationTests(ScriptCase):
    @override
    def setUp(self) -> None:
        super().setUp()
        # Only Kitty's embedded TUI imports are unavailable in the CI container.
        dependencies = {
            name: MagicMock()
            for name in (
                "kittens.tui.handler",
                "kittens.tui.line_edit",
                "kittens.tui.loop",
                "kittens.tui.operations",
                "kitty.config",
                "kitty.key_encoding",
                "kitty.typing_compat",
            )
        }
        dependencies["kittens.tui.handler"].Handler = object
        with patch.dict("sys.modules", dependencies):
            self.search = runpy.run_path(str(ROOT / "home/dot_config/kitty/search.py"))

    def test_kitty_search_rejects_bad_window_ids_before_remote_operations(self) -> None:
        self.stub("kitty", "exit 0", log=True)
        for arguments in (["search.py"], ["search.py", "invalid"]):
            with (
                self.subTest(arguments=arguments),
                patch.dict(os.environ, self.env, clear=True),
                self.assertRaises(SystemExit),
            ):
                self.search["main"](arguments)
        self.assertEqual(self.logged_calls(), [])

    def test_kitty_search_displays_marker_errors_and_recovers_after_editing(self) -> None:
        self.stub(
            "kitty",
            r"""if [ "$2" = create-marker ]; then
    echo 'Invalid regular expression' >&2; exit 23
fi""",
            log=True,
        )
        handler = self.search["Search"].__new__(self.search["Search"])
        handler.window_ids = [1]
        handler.line_edit = SimpleNamespace(current_input="[")
        handler.mode = "regex"
        handler.error = ""
        with patch.dict(os.environ, self.env, clear=True):
            handler.mark()
            self.assertIn("Invalid regular expression", handler.error)
            self.assertEqual(
                [call[2] for call in self.logged_calls()], ["create-marker", "remove-marker"]
            )
            self.stub("kitty", "exit 0")
            handler.line_edit.current_input = "valid"
            handler.mark()
            self.assertEqual(handler.error, "")


@pytest.mark.parametrize(
    ("checker_output", "expected"),
    [
        (None, "basedpyright"),
        (
            '{"version":"affected-release","summary":{"filesAnalyzed":0}}',
            "analyzed no Python files",
        ),
    ],
)
def test_validator_rejects_missing_tools_and_empty_discovery(
    tmp_path: Path, checker_output: str | None, expected: str
) -> None:
    marker = tmp_path / "pytest-called"
    for tool in ("ruff", "basedpyright", "pytest", "chezmoi", "bash", "shellcheck"):
        if tool == "basedpyright" and checker_output is None:
            continue
        body = "exit 0"
        if tool == "basedpyright":
            body = f"printf '%s\\n' '{checker_output}'"
        elif tool == "pytest":
            body = 'printf called > "$TOOL_CALLS"'
        executable = tmp_path / tool
        executable.write_text("#!/bin/sh\n" + body + "\n")
        executable.chmod(0o755)
    result = subprocess.run(
        ["/usr/bin/python3", "-B", str(ROOT / ".github/tests/validate.py")],
        env={"PATH": str(tmp_path), "TOOL_CALLS": str(marker)},
        capture_output=True,
        text=True,
        check=False,
        timeout=15,
    )
    assert result.returncode != 0
    assert expected.lower() in result.stderr.lower()
    if checker_output is None:
        assert "installed separately" in result.stderr
    assert not marker.exists()
