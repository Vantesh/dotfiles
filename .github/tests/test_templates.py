"""Real-template syntax/lint, fresh-home data, externals, and missing-tool regressions."""

import json
import re
import unittest
from pathlib import PurePosixPath

from script_helpers import CHEZMOI, PYTHON3, ROOT, SCRIPTS, SHELLCHECK, ScriptCase

# Confirmed by a clean Arch container apply: apple_cursor ships separate themes.
# Nested Hyprcursor targets are safe unless upstream adds macOS-hypr* here.
# Update this inventory when upstream changes the tarball's top-level names.
APPLE_CURSOR_TOP_LEVEL_NAMES = frozenset({"macOS", "macOS-White"})


@unittest.skipUnless(CHEZMOI, "chezmoi is required for real template rendering")
class TemplateTests(ScriptCase):
    def test_every_setup_template_has_valid_shell_syntax(self):
        paths = sorted(SCRIPTS.rglob("*.tmpl"))
        self.assertTrue(paths, "No setup templates found")
        for path in paths:
            for personal in (False, True):
                with self.subTest(script=path.name, personal=personal):
                    data = self.fixture_data()
                    data["personal"] = personal
                    source = self.render(path, data=data)
                    result = self.run_process(
                        ["bash", "-n"], input=source, name=path.name
                    )
                    self.assertEqual(result.returncode, 0, f"{path}: {result.stderr}")

    @unittest.skipUnless(
        SHELLCHECK, "shellcheck is not on PATH; rendered-script lint requires it"
    )
    def test_every_rendered_setup_template_passes_shellcheck(self):
        for path in sorted(SCRIPTS.rglob("*.tmpl")):
            for personal in (False, True):
                with self.subTest(script=path.name, personal=personal):
                    data = self.fixture_data()
                    data["personal"] = personal
                    source = self.render(path, data=data)
                    result = self.run_process(
                        [SHELLCHECK, "--shell=bash", "-"], input=source, name=path.name
                    )
                    self.assertEqual(
                        result.returncode, 0, f"{path}:\n{result.stdout}{result.stderr}"
                    )

    def test_ignore_renders_with_minimal_fixture_data(self):
        path = ROOT / "home/.chezmoiignore.tmpl"
        for personal in (False, True):
            with self.subTest(personal=personal):
                result = self.render(
                    path, data={"personal": personal, "chezmoi": {"os": "linux"}}
                )
                for rule in (
                    ".config/atuin",
                    ".config/fish/conf.d/atuin.fish",
                    ".config/git",
                ):
                    self.assertEqual(rule in result.splitlines(), not personal)
                self.assertNotIn(".chezmoiscripts/linux/**", result)

    def test_ignore_renders_in_fresh_home_without_personal_key(self):
        # A fresh execute-template/container has no persisted user [data] keys.
        # Missing-key errors must be reported, not hidden by injecting .personal.
        result = self.render(
            ROOT / "home/.chezmoiignore.tmpl", data={"chezmoi": {"os": "linux"}}
        )
        for rule in (".config/atuin", ".config/fish/conf.d/atuin.fish", ".config/git"):
            self.assertIn(rule, result.splitlines())

    def cursor_entries(self):
        path = ROOT / "home/.chezmoiexternals/00-cursors.yaml.tmpl"
        source = path.read_text()
        # Replace only GitHub asset lookups with fixture data: all conditionals,
        # target paths, archive options and YAML are rendered by chezmoi unchanged.
        # No GitHub API/cache or network access is needed.
        pattern = r'gitHubLatestReleaseAssetURL\s+(?:"[^"]+"|\$\w+)\s+"([^"]+)"'
        assets = re.findall(pattern, source)
        self.assertTrue(assets, "Expected release-asset lookups to fixture")
        source = re.sub(
            pattern,
            lambda match: "(index $.fixtureAssets " + json.dumps(match[1]) + ")",
            source,
        )
        data = self.fixture_data()
        data["fixtureAssets"] = {
            asset: f"https://fixtures.invalid/{asset}" for asset in assets
        }
        env = {key: value for key, value in self.env.items() if key != "OFFLINE"}
        rendered = self.render(path, data=data, source=source, env=env)
        self.assertTrue(
            rendered.strip(), "OFFLINE must be unset to exercise cursor entries"
        )
        # Use chezmoi's YAML parser rather than requiring an optional Python package.
        parsed = self.render(
            path,
            source="{{ .fixtureYAML | fromYaml | toJson }}",
            data={"fixtureYAML": rendered},
            env=env,
        )
        return json.loads(parsed)

    def test_cursor_archive_targets_do_not_collide_with_parent_contents(self):
        entries = self.cursor_entries()
        for target, entry in entries.items():
            if entry.get("type") != "archive":
                continue
            parent = PurePosixPath(target)
            known_names = (
                APPLE_CURSOR_TOP_LEVEL_NAMES
                if entry.get("url", "").endswith("/macOS.tar.xz")
                else frozenset()
            )
            for child in map(PurePosixPath, entries):
                if parent not in child.parents:
                    continue
                with self.subTest(parent=str(parent), child=str(child)):
                    self.assertNotIn(
                        child.relative_to(parent).parts[0],
                        known_names,
                        "Parent archive contains the nested target directory; "
                        "overlapping contents can cause chezmoi 'inconsistent state'",
                    )

    def test_apple_cursor_preserves_multiple_top_level_themes(self):
        entries = self.cursor_entries()
        apple = [
            entry
            for entry in entries.values()
            if entry.get("url", "").endswith("/macOS.tar.xz")
        ]
        self.assertEqual(len(apple), 1, "Expected exactly one apple_cursor archive")
        self.assertNotIn(
            "stripComponents",
            apple[0],
            "apple_cursor macOS.tar.xz contains multiple top-level themes; "
            "stripping merges them and causes chezmoi 'inconsistent state'",
        )

    def test_template_shellouts_have_missing_tool_guards(self):
        # Examine template actions, not literal script bodies (e.g. runtime jq).
        # A static guard check avoids ever invoking an unguarded secret provider.
        shellouts = re.compile(
            r"\b(output(?:List)?|onepassword\w*|bitwarden\w*|"
            r'pass(?:Fields)?|gopass|keepassxc\w*)\s+"([^"]+)"'
        )
        minimal_env = dict(self.env, PATH=str(self.bin / "empty"))
        (self.bin / "empty").mkdir()
        for path in sorted((ROOT / "home").rglob("*.tmpl")):
            source = path.read_text()
            actions = "\n".join(re.findall(r"{{-?(.*?)-?}}", source, re.S))
            calls = shellouts.findall(actions)
            if not calls:
                continue
            with self.subTest(template=str(path.relative_to(ROOT))):
                for function, argument in calls:
                    tool = (
                        argument
                        if function.startswith("output")
                        else {
                            "pass": "pass",
                            "passFields": "pass",
                            "gopass": "gopass",
                        }.get(
                            function,
                            "op"
                            if function.startswith("onepassword")
                            else "bw"
                            if function.startswith("bitwarden")
                            else "keepassxc-cli",
                        )
                    )
                    self.assertRegex(
                        actions,
                        r'\blookPath\s+"' + re.escape(tool) + '"',
                        f"{path}: {function} invokes {tool!r} without a lookPath guard",
                    )
                self.render(path, env=minimal_env)

    @unittest.skipUnless(
        PYTHON3, "python3 is required to execute the Spotifast modify script"
    )
    def test_spotifast_settings_work_without_secret_tools(self):
        path = ROOT / "home/dot_config/spotifast/modify_settings.json.tmpl"
        minimal = self.directory / "empty-path"
        minimal.mkdir()
        env = dict(self.env, PATH=str(minimal))
        source = self.render(path, data={"personal": False}, env=env)
        script = self.directory / "spotifast-settings.py"
        script.write_text(source)
        # Absolute python is the harness interpreter, not a tool on the target PATH.
        result = self.run_process(
            [PYTHON3, str(script)],
            input='{"application_state": 42}',
            env=env,
            name=str(path),
        )
        self.assertEqual(
            result.returncode,
            0,
            f"Spotifast must render/apply without jq or vault tools:\n{result.stderr}",
        )
        data = json.loads(result.stdout)
        self.assertEqual(data["application_state"], 42)
        self.assertEqual(data["custom_theme"], "noctalia.json")
        self.assertNotIn("web_client_id", data)
