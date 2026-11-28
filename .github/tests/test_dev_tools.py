"""Repository development tools and tasks are isolated from bootstrap/provisioning."""

from __future__ import annotations

import re
import tomllib
from pathlib import Path
from typing import cast

import pytest
from helpers import ROOT, python_package_pins

DEV_CONFIG = ROOT / "mise/config.development.toml"
MISE_RC = ROOT / ".miserc.toml"
PYPROJECT = ROOT / "pyproject.toml"
BASH_CONFIG = ROOT / "home/dot_bashrc"
FISH_CONFIG = ROOT / "home/dot_config/private_fish/config.fish.tmpl"
CI_WORKFLOW = ROOT / ".github/workflows/ci-dots.yaml"
README = ROOT / ".github/README.md"
MISE_DIR = DEV_CONFIG.parent
MISE_RELATIVE_DIR = Path("mise")
CHEZMOI_SCRIPTS_RELATIVE_DIR = Path("home/.chezmoiscripts")
PROVISIONING_LIB_RELATIVE_DIR = Path("home/.chezmoitemplates/lib")

FORBIDDEN_PROVISIONING_REFERENCES = (
    "mise/config.development",
    "--env development",
    "MISE_ENV=development",
    "mise install",
    "pytest",
)
TOOL_VERSION = re.compile(r"[0-9][0-9A-Za-z.+-]*")


def _table(data: dict[str, object], name: str) -> dict[str, object]:
    value = data[name]
    assert isinstance(value, dict), f"{name} must be a table"
    return cast("dict[str, object]", value)


def _section(config: Path, name: str) -> dict[str, object]:
    data = cast("dict[str, object]", tomllib.loads(config.read_text()))
    return _table(data, name)


def _is_development_config(path: Path, mise_dir: Path) -> bool:
    relative = path.relative_to(mise_dir)
    # Without env_conf_d, Mise loads every non-hidden conf.d TOML unconditionally,
    # even names such as config.development.toml.
    if relative.parts[0] == "conf.d":
        return False
    parts = [part.removesuffix(".toml") for part in relative.parts]
    return any(part == "development" or part.endswith(".development") for part in parts)


def _bootstrap_configs(root: Path) -> list[Path]:
    mise_dir = root / MISE_RELATIVE_DIR
    return sorted(
        path
        for path in mise_dir.rglob("*.toml")
        if path.is_file()
        and not any(part.startswith(".") for part in path.relative_to(mise_dir).parts)
        and not _is_development_config(path, mise_dir)
    )


def _provisioning_files(root: Path) -> list[Path]:
    scripts = root / CHEZMOI_SCRIPTS_RELATIVE_DIR
    library = root / PROVISIONING_LIB_RELATIVE_DIR
    candidates = [
        *scripts.rglob("run_*"),
        *library.rglob("*.py"),
        *library.rglob("*.py.tmpl"),
    ]
    return sorted(path for path in candidates if path.is_file())


def _assert_bootstrap_configs(root: Path) -> list[Path]:
    configs = _bootstrap_configs(root)
    assert configs, "No bootstrap Mise configurations were discovered"

    for config in configs:
        try:
            data = cast("dict[str, object]", tomllib.loads(config.read_text()))
        except tomllib.TOMLDecodeError as error:
            raise AssertionError(f"Invalid bootstrap Mise config {config}: {error}") from error

        for section in ("tools", "tasks"):
            assert section not in data, (
                f"{config}: bootstrap Mise config must not declare [{section}]"
            )

    return configs


def _assert_provisioning_files(root: Path) -> list[Path]:
    paths = _provisioning_files(root)
    assert paths, "No Chezmoi provisioning scripts or templates were discovered"

    for path in paths:
        text = path.read_text()
        for reference in FORBIDDEN_PROVISIONING_REFERENCES:
            assert reference not in text, f"{path}: provisioning must not reference {reference!r}"

    return paths


def test_development_tools_are_pinned_in_isolated_mise_environment() -> None:
    tools = _section(DEV_CONFIG, "tools")

    assert set(tools) == {"python", "uv", "ruff", "pypi:pyrefly", "shellcheck"}
    assert tools["python"] == "3.14"
    for name, value in tools.items():
        if name == "python":
            continue
        assert isinstance(value, str), f"{name} must be a version string"
        assert TOOL_VERSION.fullmatch(value), f"{name} must be an exact version: {value!r}"

    settings = _section(DEV_CONFIG, "settings")
    assert settings["experimental"] is True
    python_settings = _table(settings, "python")
    assert python_settings["venv_stdlib"] is True

    env = _section(DEV_CONFIG, "env")
    env_python = _table(_table(env, "_"), "python")
    assert env_python["venv"] == {"path": ".venv", "create": True}


def test_python_packages_are_declared_once_in_mise() -> None:
    deps = _section(DEV_CONFIG, "deps")
    python = _table(deps, "python")

    assert python["auto"] is True
    assert python["sources"] == ["mise/config.development.toml"]
    assert python["outputs"] == [".venv"]

    command = python["run"]
    assert isinstance(command, str)
    pins = python_package_pins(command)
    assert set(pins) == {"pytest", "loguru"}

    config_text = DEV_CONFIG.read_text()
    for name, version in pins.items():
        assert config_text.count(f"{name}=={version}") == 1
    assert not (ROOT / "requirements.txt").exists()
    assert not (ROOT / "uv.lock").exists()
    assert not list(MISE_DIR.rglob("*.lock"))

    pyproject = cast("dict[str, object]", tomllib.loads(PYPROJECT.read_text()))
    assert set(pyproject) == {"tool"}
    tool = _table(pyproject, "tool")
    assert set(tool) == {"pyrefly", "pytest"}
    assert "project" not in tool
    assert "dependency-groups" not in pyproject


def test_canonical_tasks_format_then_check_once() -> None:
    tasks = _section(DEV_CONFIG, "tasks")

    assert set(tasks) == {"dev", "check"}
    for name, value in tasks.items():
        task = cast("dict[str, object]", value)
        assert task["description"], f"{name} must have a description"
        assert task["run"]

    dev = cast("dict[str, object]", tasks["dev"])
    check = cast("dict[str, object]", tasks["check"])
    assert "depends" not in dev
    assert "depends" not in check
    assert dev["run"] == ["ruff format .", {"task": "check"}]
    assert check["run"] == ["python3 -B .github/tests/validate.py"]


def test_repository_selects_development_environment_automatically() -> None:
    mise_rc = cast("dict[str, object]", tomllib.loads(MISE_RC.read_text()))
    environments = mise_rc["env"]
    assert isinstance(environments, list), ".miserc.toml env must be a list"
    assert "development" in environments

    workflow = CI_WORKFLOW.read_text()
    assert "mise run check" in workflow
    assert "MISE_AUTO_ENV" not in workflow
    assert "MISE_TRUSTED_CONFIG_PATHS: ${{ github.workspace }}" in workflow
    # Provisioning scripts run under /usr/bin/python3 even after sudo resets the
    # environment, so CI needs the host package rather than the Mise venv.
    assert "python-loguru" in workflow
    assert "python-pytest" not in workflow

    for path in (DEV_CONFIG, BASH_CONFIG, FISH_CONFIG, CI_WORKFLOW, README):
        text = path.read_text()
        assert "--env development" not in text, f"explicit env selection remains in {path}"
        assert "MISE_ENV=development" not in text, f"explicit env selection remains in {path}"


def test_bootstrap_and_provisioning_do_not_load_development_tools() -> None:
    configs = _assert_bootstrap_configs(ROOT)
    assert DEV_CONFIG not in configs, "the development config must not be treated as bootstrap"

    _assert_provisioning_files(ROOT)


def test_boundary_checks_detect_new_discovered_violations(tmp_path: Path) -> None:
    dev_only = tmp_path / "mise/conf.d/config.development.toml"
    dev_only.parent.mkdir(parents=True)
    dev_only.write_text('[tools]\nruff = "0.17.6"\n')
    dev_directory = tmp_path / "mise/development/config.toml"
    dev_directory.parent.mkdir(parents=True)
    dev_directory.write_text('[tools]\nruff = "0.17.6"\n')
    similarly_named = tmp_path / "mise/conf.d/development-tools.toml"
    similarly_named.write_text("# ordinary bootstrap configuration\n")

    discovered = _bootstrap_configs(tmp_path)
    assert dev_only in discovered, "unconditional conf.d fragments load during bootstrap"
    assert dev_directory not in discovered, "a development/ config must be excluded"
    assert similarly_named in discovered, "development-tools.toml must remain bootstrap"

    with pytest.raises(AssertionError, match=r"must not declare \[tools\]") as violation:
        _assert_bootstrap_configs(tmp_path)
    assert str(violation.value).startswith(f"{dev_only}: "), (
        "the conf.d [tools] declaration must fail the bootstrap boundary check"
    )

    script = tmp_path / "home/.chezmoiscripts/linux/run_after_99_probe.py"
    script.parent.mkdir(parents=True)
    script.write_text("import pytest\n")

    with pytest.raises(AssertionError, match="must not reference 'pytest'"):
        _assert_provisioning_files(tmp_path)


def test_interactive_shells_activate_mise_once_and_ci_does_not() -> None:
    bash = BASH_CONFIG.read_text()
    fish = FISH_CONFIG.read_text()
    workflow = CI_WORKFLOW.read_text()

    assert bash.count('eval "$(mise activate bash)"') == 1
    assert fish.count("mise activate fish | source") == 1
    assert "activate bash" not in workflow
    assert "activate fish" not in workflow
