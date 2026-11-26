"""Renovate keeps the Maple Mono zip version and checksum paired."""

import json
import re
from typing import cast

from helpers import ROOT

CONFIG = ROOT / "renovate.json5"
ASSETS = ROOT / "home/.chezmoidata/external_assets.yaml"
FONTS = ROOT / "home/.chezmoiexternals/00-fonts.yaml.tmpl"

ASSET = "MapleMono-NF-unhinted.zip"
GOOD_DIGEST = "a" * 64
VERSION_PATTERN = re.compile(r"v\d+(?:\.\d+)+")
SHA256_PATTERN = re.compile(r"[0-9a-f]{64}")


def _config() -> dict[str, object]:
    return cast("dict[str, object]", json.loads(CONFIG.read_text()))


def _manager() -> dict[str, object]:
    managers = cast("list[dict[str, object]]", _config()["customManagers"])
    for manager in managers:
        template = manager.get("autoReplaceStringTemplate")
        if isinstance(template, str) and 'sha256: "{{{newDigest}}}"' in template:
            return manager
    raise AssertionError("no manager updates a version and SHA-256 pair together")


def _maple_entry() -> re.Match[str]:
    patterns = cast("list[str]", _manager()["matchStrings"])
    assert len(patterns) == 1
    # Renovate uses JavaScript named groups; Python spells them the same way
    # after this mapping.
    pattern = re.compile(patterns[0].replace("(?<", "(?P<"))
    matches = [
        match for match in pattern.finditer(ASSETS.read_text()) if match["depName"] == "maple-mono"
    ]
    assert len(matches) == 1
    return matches[0]


def _replacement(template: str, values: dict[str, str]) -> str:
    return re.sub(r"\{\{\{(\w+)\}\}\}", lambda match: values[match[1]], template)


def test_declaration_pins_the_exact_zip_and_checksum() -> None:
    match = _maple_entry()
    assert match["datasource"] == "custom.maple-mono"
    assert match["packageName"] == "subframe7536/maple-font"
    assert match["versioning"] == "loose"
    assert VERSION_PATTERN.fullmatch(match["currentValue"])
    assert SHA256_PATTERN.fullmatch(match["currentDigest"])


def test_manager_rewrites_only_the_version_and_checksum() -> None:
    match = _maple_entry()
    template = cast("str", _manager()["autoReplaceStringTemplate"])
    values = {**match.groupdict(), "newValue": "v9.9", "newDigest": GOOD_DIGEST}
    source = ASSETS.read_text()
    updated = source[: match.start()] + _replacement(template, values) + source[match.end() :]

    before = source.splitlines()
    after = updated.splitlines()
    assert len(before) == len(after)
    assert [line for line, new in zip(before, after, strict=True) if line != new] == [
        f'    version: "{match["currentValue"]}"',
        f'    sha256: "{match["currentDigest"]}"',
    ]
    assert 'version: "v9.9"' in updated
    assert f'sha256: "{GOOD_DIGEST}"' in updated


def test_install_uses_the_pinned_version_and_checksum() -> None:
    text = FONTS.read_text()
    assert f'releases/download/{{{{ $assets.mapleMonoNerdFont.version }}}}/{ASSET}"' in text
    assert "sha256: {{ $assets.mapleMonoNerdFont.sha256 | quote }}" in text


def test_custom_datasource_selects_the_exact_release_asset() -> None:
    datasources = cast("dict[str, object]", _config()["customDatasources"])
    datasource = cast("dict[str, object]", datasources["maple-mono"])
    assert datasource["defaultRegistryUrlTemplate"] == (
        "https://api.github.com/repos/{{packageName}}/releases?per_page=100"
    )
    expressions = cast("list[str]", datasource["transformTemplates"])
    assert len(expressions) == 2
    assert all(ASSET in expression for expression in expressions)
    assert "draft" in expressions[0] and "prerelease" in expressions[0]
    assert "$count(" in expressions[0] and "= 1" in expressions[0]
    assert "sha256:" in expressions[1]
