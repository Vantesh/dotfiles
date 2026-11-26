"""Renovate custom managers extract the dependency identities they own."""

import json
import os
import re
import shutil
import subprocess
from pathlib import Path
from typing import TypedDict, cast

import pytest
from helpers import ROOT, renovate_command

CONFIG = ROOT / "renovate.json5"
SHA256 = re.compile(r"[0-9a-f]{64}")
SEMVER = re.compile(r"\d+\.\d+\.\d+")

EXTERNAL_ASSETS = r"""externalAssets:
  macTahoeCursorLight:
    # renovate: datasource=github-release-attachments packageName=Vantesh/mactahoe-hyprcursor depName=mactahoe-cursor-light versioning=loose
    version: "v1.0.2-839848b9a8a3"
    sha256: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

  macTahoeCursorDark:
    # renovate: datasource=github-release-attachments packageName=Vantesh/mactahoe-hyprcursor depName=mactahoe-cursor-dark versioning=loose
    version: "v1.0.2-839848b9a8a3"
    sha256: "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"

  appleColorEmoji:
    # renovate: datasource=github-release-attachments packageName=samuelngs/apple-emoji-ttf depName=apple-color-emoji versioning=regex:^macos-(?<major>\d+)-(?<minor>\d{8})-[0-9a-f]+$
    version: "macos-26-20260722-484daf4e"
    sha256: "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"

  autoCpufreq:
    # renovate: datasource=github-tags packageName=AdnanHodzic/auto-cpufreq depName=auto-cpufreq versioning=semver
    version: "v3.2.0"
    commit: "35d8015afc1bc2c4b30526828dddde4c53925976"

  colloidIconTheme:
    # renovate: datasource=github-tags packageName=vinceliuice/Colloid-icon-theme depName=colloid-icon-theme versioning=regex:^(?<major>\d{4})-(?<minor>\d{2})-(?<patch>\d{2})$
    version: "2026-08-10"
    commit: "e3a8f89fac888af715233f8f8ef0a5b1e350f0dd"

  fisher:
    # renovate: datasource=github-tags packageName=jorgebucaran/fisher depName=fisher versioning=semver
    version: "4.4.8"
    commit: "a04308be92daa6cfecdbb0ca58b1e8508664cff2"
"""

MPV_TEMPLATE = """{{- $glass := "https://raw.githubusercontent.com/Demetter/ModernGlass/631ba4888b6c1dfa1122db36c90ba3d20c8d3b43" }}
".config/mpv/scripts/modernz.lua":
  type: file
  url: "{{ $glass }}/modernz.lua"
"""

CI_WORKFLOW = """\
jobs:
  test:
    steps:
      - run: |
          uv tool install --python /usr/bin/python3 --with pytest --with loguru pyrefly
          npm install --global --no-fund --no-audit renovate@9.8.7
"""


class Dependency(TypedDict):
    depName: str
    packageName: str
    currentValue: str
    currentDigest: str
    datasource: str
    versioning: str
    replaceString: str


def _renovate_environment(tmp_path: Path) -> dict[str, str]:
    original_cache = os.environ.get("XDG_CACHE_HOME") or str(Path.home() / ".cache")
    return {
        **os.environ,
        "HOME": str(tmp_path / "home"),
        "XDG_CACHE_HOME": str(tmp_path / "cache"),
        "XDG_CONFIG_HOME": str(tmp_path / "config"),
        "XDG_DATA_HOME": str(tmp_path / "data"),
        "XDG_STATE_HOME": str(tmp_path / "state"),
        "npm_config_cache": str(Path(original_cache) / "npm"),
        "LOG_FORMAT": "json",
        "LOG_LEVEL": "info",
    }


def _run_renovate(repository: Path, tmp_path: Path) -> dict[str, Dependency]:
    environment = _renovate_environment(tmp_path)
    result = subprocess.run(
        renovate_command(
            "--platform=local",
            "--dry-run=extract",
            "--base-dir",
            str(tmp_path / "base"),
            "--require-config=ignored",
        ),
        cwd=repository,
        env=environment,
        capture_output=True,
        text=True,
        check=False,
        timeout=120,
    )
    assert result.returncode == 0, result.stderr

    for line in result.stdout.splitlines():
        try:
            record = cast("dict[str, object]", json.loads(line))
        except json.JSONDecodeError:
            continue
        if record.get("msg") != "Extracted dependencies":
            continue
        package_files = cast("dict[str, list[dict[str, object]]]", record["packageFiles"])
        dependencies = [
            cast("Dependency", dependency)
            for package_file in package_files.get("regex", [])
            for dependency in cast("list[object]", package_file["deps"])
        ]
        return {dependency["depName"]: dependency for dependency in dependencies}

    raise AssertionError(f"Renovate did not report extracted dependencies:\n{result.stdout}")


def test_renovate_subprocess_shares_npm_cache(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    shared_cache = tmp_path / "shared-cache"
    isolated = tmp_path / "isolated"
    monkeypatch.setenv("XDG_CACHE_HOME", str(shared_cache))

    environment = _renovate_environment(isolated)

    assert environment["npm_config_cache"] == str(shared_cache / "npm")
    assert environment["HOME"] == str(isolated / "home")
    assert environment["XDG_CACHE_HOME"] == str(isolated / "cache")
    assert environment["XDG_CONFIG_HOME"] == str(isolated / "config")
    assert environment["XDG_DATA_HOME"] == str(isolated / "data")
    assert environment["XDG_STATE_HOME"] == str(isolated / "state")


def _extract(tmp_path: Path) -> dict[str, Dependency]:
    repository = tmp_path / "repository"
    (repository / ".github/workflows").mkdir(parents=True)
    (repository / "home/.chezmoidata").mkdir(parents=True)
    (repository / "home/.chezmoiexternals").mkdir(parents=True)
    _ = shutil.copyfile(CONFIG, repository / "renovate.json5")
    (repository / ".github/workflows/ci-dots.yaml").write_text(CI_WORKFLOW)
    (repository / "home/.chezmoidata/external_assets.yaml").write_text(EXTERNAL_ASSETS)
    (repository / "home/.chezmoiexternals/10-mpv.yaml.tmpl").write_text(MPV_TEMPLATE)
    return _run_renovate(repository, tmp_path)


@pytest.fixture(scope="module")
def extracted(tmp_path_factory: pytest.TempPathFactory) -> dict[str, Dependency]:
    return _extract(tmp_path_factory.mktemp("renovate"))


@pytest.fixture(scope="module")
def production_extracted(
    tmp_path_factory: pytest.TempPathFactory,
) -> dict[str, Dependency]:
    tmp_path = tmp_path_factory.mktemp("renovate-production")
    repository = tmp_path / "repository"
    (repository / ".github/workflows").mkdir(parents=True)
    _ = shutil.copyfile(
        ROOT / ".github/workflows/ci-dots.yaml",
        repository / ".github/workflows/ci-dots.yaml",
    )
    _ = shutil.copyfile(CONFIG, repository / "renovate.json5")
    return _run_renovate(repository, tmp_path)


def _dependency(dependencies: dict[str, Dependency], name: str) -> Dependency:
    dependency = dependencies.get(name)
    assert dependency is not None, f"missing extracted dependency {name}"
    return dependency


def test_release_attachments_extract_distinct_mactahoe_assets(
    extracted: dict[str, Dependency],
) -> None:
    light = _dependency(extracted, "mactahoe-cursor-light")
    dark = _dependency(extracted, "mactahoe-cursor-dark")

    assert light["packageName"] == dark["packageName"] == "Vantesh/mactahoe-hyprcursor"
    assert light["currentDigest"] != dark["currentDigest"]

    for dependency in (light, dark):
        assert dependency["datasource"] == "github-release-attachments"
        assert dependency["versioning"] == "loose"
        assert dependency["currentValue"] == "v1.0.2-839848b9a8a3"
        assert SHA256.fullmatch(dependency["currentDigest"])
        assert f'version: "{dependency["currentValue"]}"' in dependency["replaceString"]
        assert f'sha256: "{dependency["currentDigest"]}"' in dependency["replaceString"]


def test_release_attachments_extract_apple_color_emoji(
    extracted: dict[str, Dependency],
) -> None:
    dependency = _dependency(extracted, "apple-color-emoji")

    assert dependency["packageName"] == "samuelngs/apple-emoji-ttf"
    assert dependency["datasource"] == "github-release-attachments"
    assert dependency["versioning"] == r"regex:^macos-(?<major>\d+)-(?<minor>\d{8})-[0-9a-f]+$"
    assert dependency["currentValue"] == "macos-26-20260722-484daf4e"
    assert dependency["currentDigest"] == (
        "cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"
    )
    assert f'version: "{dependency["currentValue"]}"' in dependency["replaceString"]
    assert f'sha256: "{dependency["currentDigest"]}"' in dependency["replaceString"]


@pytest.mark.parametrize(
    ("name", "package", "version", "commit", "versioning"),
    [
        (
            "auto-cpufreq",
            "AdnanHodzic/auto-cpufreq",
            "v3.2.0",
            "35d8015afc1bc2c4b30526828dddde4c53925976",
            "semver",
        ),
        (
            "colloid-icon-theme",
            "vinceliuice/Colloid-icon-theme",
            "2026-08-10",
            "e3a8f89fac888af715233f8f8ef0a5b1e350f0dd",
            r"regex:^(?<major>\d{4})-(?<minor>\d{2})-(?<patch>\d{2})$",
        ),
        (
            "fisher",
            "jorgebucaran/fisher",
            "4.4.8",
            "a04308be92daa6cfecdbb0ca58b1e8508664cff2",
            "semver",
        ),
    ],
)
def test_github_tags_extract_tag_and_commit_pairs(
    extracted: dict[str, Dependency],
    name: str,
    package: str,
    version: str,
    commit: str,
    versioning: str,
) -> None:
    dependency = _dependency(extracted, name)

    assert dependency["packageName"] == package
    assert dependency["datasource"] == "github-tags"
    assert dependency["versioning"] == versioning
    assert dependency["currentValue"] == version
    assert dependency["currentDigest"] == commit
    assert f'version: "{version}"' in dependency["replaceString"]
    assert f'commit: "{commit}"' in dependency["replaceString"]


def test_modernglass_extracts_repository_and_commit(extracted: dict[str, Dependency]) -> None:
    dependency = _dependency(extracted, "ModernGlass mpv scripts")

    assert dependency["packageName"] == "https://github.com/Demetter/ModernGlass"
    assert dependency["datasource"] == "git-refs"
    assert dependency["currentValue"] == "main"
    assert dependency["currentDigest"] == "631ba4888b6c1dfa1122db36c90ba3d20c8d3b43"
    assert dependency["replaceString"] == f"ModernGlass/{dependency['currentDigest']}"


def test_ci_npm_tool_pin_extracts_version(extracted: dict[str, Dependency]) -> None:
    dependency = _dependency(extracted, "renovate")

    assert dependency["packageName"] == "renovate"
    assert dependency["datasource"] == "npm"
    assert dependency["versioning"] == "semver"
    assert dependency["currentValue"] == "9.8.7"
    assert dependency["replaceString"] == "renovate@9.8.7"


def test_production_workflow_extracts_renovate_cli(
    production_extracted: dict[str, Dependency],
) -> None:
    workflow = (ROOT / ".github/workflows/ci-dots.yaml").read_text()

    renovate = _dependency(production_extracted, "renovate")
    assert renovate["datasource"] == "npm"
    assert renovate["versioning"] == "semver"
    assert SEMVER.fullmatch(renovate["currentValue"])
    assert renovate["replaceString"] == f"renovate@{renovate['currentValue']}"
    assert renovate["replaceString"] in workflow
