"""External dependency declarations stay pinned to immutable references."""

import re

from helpers import ROOT

AFFECTED = (
    ROOT / "home/.chezmoiscripts/linux/run_onchange_before_06_laptop_power.py.tmpl",
    ROOT / "home/.chezmoiscripts/linux/run_onchange_after_01_theming.py.tmpl",
    ROOT / "home/.chezmoiexternals/00-cursors.yaml.tmpl",
    ROOT / "home/.chezmoiexternals/00-fonts.yaml.tmpl",
    ROOT / "home/.chezmoidata/external_assets.yaml",
    ROOT / "home/dot_config/private_fish/config.fish.tmpl",
    ROOT / "home/dot_config/private_fish/fish_plugins.tmpl",
)
SHA256 = re.compile(r"[0-9a-f]{64}")
COMMIT = re.compile(r"[0-9a-f]{40}")


def test_affected_dependencies_do_not_use_floating_release_urls() -> None:
    for path in AFFECTED:
        source = path.read_text()
        assert "releases/latest" not in source, path
        assert "gitHubLatestReleaseAssetURL" not in source, path


def test_laptop_power_reads_its_pins_from_external_assets() -> None:
    template = (
        ROOT / "home/.chezmoiscripts/linux/run_onchange_before_06_laptop_power.py.tmpl"
    ).read_text()
    assert "{{ .externalAssets.autoCpufreq.version | toJson }}" in template
    assert "{{ .externalAssets.autoCpufreq.commit | toJson }}" in template
    assert COMMIT.search(template) is None


def test_declared_versions_commits_and_checksums_are_immutable() -> None:
    assets = (ROOT / "home/.chezmoidata/external_assets.yaml").read_text()
    versions = re.findall(r'^\s+version: "([^"]+)"$', assets, re.MULTILINE)
    commits = re.findall(r'^\s+commit: "([^"]+)"$', assets, re.MULTILINE)
    checksums = re.findall(r'^\s+sha256: "([^"]+)"$', assets, re.MULTILINE)
    assert versions
    assert all(version not in ("latest", "main", "master") for version in versions)
    assert commits and all(COMMIT.fullmatch(commit) for commit in commits)
    assert checksums and all(SHA256.fullmatch(checksum) for checksum in checksums)

    fisher = (ROOT / "home/dot_config/private_fish/config.fish.tmpl").read_text()
    plugins = (ROOT / "home/dot_config/private_fish/fish_plugins.tmpl").read_text()
    assert "fisher install jorgebucaran/fisher@$fisher_commit" in fisher
    assert "jorgebucaran/fisher@{{ .externalAssets.fisher.commit }}" in plugins
