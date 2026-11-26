"""External dependency declarations stay pinned to immutable references."""

import json
import os
import re
import subprocess
import tempfile
from pathlib import Path
from typing import cast

import pytest
from helpers import CHEZMOI, ROOT

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
WORKFLOWS = ROOT / ".github/workflows"
LOCAL_REFERENCE = "./"
DOCKER_REFERENCE = "docker://"


def _parse_yaml(source: str) -> object:
    """Parse YAML through chezmoi, the repository's existing YAML parser."""
    if CHEZMOI is None:
        pytest.skip("chezmoi is required to parse workflow YAML")
    assert CHEZMOI is not None
    with tempfile.TemporaryDirectory() as directory:
        home = Path(directory)
        environment = {
            **os.environ,
            "HOME": str(home),
            "XDG_CONFIG_HOME": str(home / ".config"),
            "XDG_CACHE_HOME": str(home / ".cache"),
            "XDG_DATA_HOME": str(home / ".local/share"),
            "XDG_STATE_HOME": str(home / ".local/state"),
        }
        result = subprocess.run(
            [CHEZMOI, "execute-template", "--override-data", json.dumps({"source": source})],
            input="{{ (fromYaml .source) | toJson }}",
            capture_output=True,
            text=True,
            check=False,
            env=environment,
        )
    if result.returncode:
        raise ValueError(result.stderr.strip())
    return json.loads(result.stdout)


def _workflow_references(workflow: object) -> list[object]:
    if not isinstance(workflow, dict):
        return []
    jobs = cast("dict[str, object]", workflow).get("jobs")
    if not isinstance(jobs, dict):
        return []
    references: list[object] = []
    for job in cast("dict[str, object]", jobs).values():
        if not isinstance(job, dict):
            continue
        job_data = cast("dict[str, object]", job)
        if "uses" in job_data:
            references.append(job_data["uses"])
        steps = job_data.get("steps")
        if not isinstance(steps, list):
            continue
        for step in cast("list[object]", steps):
            if not isinstance(step, dict):
                continue
            step_data = cast("dict[str, object]", step)
            if "uses" in step_data:
                references.append(step_data["uses"])
    return references


def _reference_error(reference: object) -> str | None:
    if not isinstance(reference, str) or not reference.strip():
        return "missing or non-string action reference"
    if reference.startswith((LOCAL_REFERENCE, DOCKER_REFERENCE)):
        # Local actions have no upstream ref. Docker container actions are
        # governed by image digests rather than Git commit SHAs.
        return None
    if any(character.isspace() for character in reference):
        return f"malformed action reference {reference!r}"
    action, separator, ref = reference.rpartition("@")
    if not separator or not action or not ref or "@" in action:
        return (
            f"malformed action reference {reference!r}: expected <action>@<40-character commit SHA>"
        )
    if not COMMIT.fullmatch(ref):
        return f"action reference {reference!r} is not pinned to a full 40-character commit SHA"
    return None


def _workflow_errors(workflow: object) -> list[str]:
    errors: list[str] = []
    for reference in _workflow_references(workflow):
        error = _reference_error(reference)
        if error is not None:
            errors.append(error)
    return errors


def _yaml_errors(source: str) -> list[str]:
    return _workflow_errors(_parse_yaml(source))


def _inspect_workflows(directory: Path) -> tuple[int, list[str]]:
    references = 0
    errors: list[str] = []
    for path in sorted(directory.rglob("*.y*ml")):
        try:
            workflow = _parse_yaml(path.read_text())
        except ValueError as error:
            errors.append(f"{path}: {error}")
            continue
        for reference in _workflow_references(workflow):
            references += 1
            error = _reference_error(reference)
            if error is not None:
                errors.append(f"{path}: {error}")
    return references, errors


def _step_workflow(uses: str) -> str:
    return f"""jobs:
  test:
    steps:
      - uses: {uses}
"""


def _reusable_workflow(uses: str) -> str:
    return f"""jobs:
  test:
    uses: {uses}
"""


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


def test_full_sha_action_reference_is_allowed() -> None:
    reference = "actions/checkout@fbc6f3992d24b796d5a048ff273f7fcc4a7b6c09"
    assert _yaml_errors(_step_workflow(reference)) == []


def test_full_sha_reusable_workflow_reference_is_allowed() -> None:
    reference = "owner/repo/.github/workflows/ci.yml@0123456789abcdef0123456789abcdef01234567"
    assert _yaml_errors(_reusable_workflow(reference)) == []


def test_local_action_reference_is_allowed() -> None:
    assert _yaml_errors(_step_workflow("./.github/actions/setup")) == []


def test_mutable_version_tag_is_rejected() -> None:
    assert _yaml_errors(_step_workflow("actions/checkout@v5"))


def test_branch_reference_is_rejected() -> None:
    assert _yaml_errors(_step_workflow("actions/checkout@main"))


def test_short_sha_is_rejected() -> None:
    assert _yaml_errors(_step_workflow("actions/checkout@fbc6f39"))


def test_malformed_or_missing_reference_is_rejected() -> None:
    assert _yaml_errors(_step_workflow("actions/checkout"))
    assert _yaml_errors(
        """jobs:
  test:
    steps:
      - uses:
"""
    )


def test_multiple_workflow_files_are_covered(tmp_path: Path) -> None:
    (tmp_path / "one.yaml").write_text(_step_workflow("actions/checkout@v5"))
    (tmp_path / "two.yml").write_text(_step_workflow("actions/checkout@main"))

    references, errors = _inspect_workflows(tmp_path)

    assert references == 2
    assert len(errors) == 2
    assert "one.yaml" in "\n".join(errors)
    assert "two.yml" in "\n".join(errors)


def test_repository_workflows_pin_all_action_references() -> None:
    references, errors = _inspect_workflows(WORKFLOWS)

    assert references
    assert not errors, "\n".join(errors)
