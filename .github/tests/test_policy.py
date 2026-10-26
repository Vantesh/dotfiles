"""Personal policy publication through real Chezmoi scripts and isolated system files."""

import json
import shutil
from pathlib import Path

import pytest
from helpers import CHEZMOI, ROOT, SCRIPTS
from test_setup import calls, render_python, run_setup, stub
from test_setup import env as env

HOOKS = ("run_onchange_before_01_sudo.py", "run_onchange_before_03_pacman.py.tmpl")


@pytest.fixture
def policy(env: dict[str, str], tmp_path: Path) -> dict[str, str]:
    source = tmp_path / "checkout with spaces/home"
    scripts = source / ".chezmoiscripts/linux"
    scripts.mkdir(parents=True)
    etc = tmp_path / "etc"
    for directory in (etc / "sudoers.d", etc / "security", etc / "conf.d"):
        directory.mkdir(parents=True, mode=0o750)
    (etc / "sudoers").write_text(f"Defaults lecture=never\n@includedir {etc / 'sudoers.d'}\n")
    (etc / "sudoers.d/timeout").write_text("Defaults passwd_timeout=5\n")
    (etc / "sudoers.d/timeout").chmod(0o440)
    (etc / "sudoers.d/unmanaged").write_text("Defaults insults\n")
    (etc / "security/faillock.conf").write_text("# keep\n# deny = 3\nlocal_users_only\n")
    (etc / "security/faillock.conf").chmod(0o640)
    (etc / "pacman-options").write_text("NoExtract = etc/custom !etc/pacman.d/mirrorlist\n")
    (etc / "pacman.conf").write_text(
        f"# keep\n[options]\nArchitecture = auto\n#Color\n#VerbosePkgLists\n#ParallelDownloads = 5\nInclude = {etc / 'pacman-options'}\n\n[custom]\nServer = https://example.invalid/$repo/os/$arch\n"
    )
    (etc / "pacman.conf").chmod(0o640)
    (etc / "conf.d/pacman-contrib").write_text("# cache\nPACCACHE_ARGS='-k3'\nOTHER=keep\n")
    shutil.copytree(ROOT / "mise", source.parent / "mise")
    shutil.copytree(ROOT / "home/.chezmoitemplates/lib", source / ".chezmoitemplates/lib")
    # Only fixture copies waive root identity; all target paths are private.
    for name in HOOKS:
        text = (SCRIPTS / name).read_text()
        for path in (
            "/etc/sudoers.d",
            "/etc/sudoers",
            "/etc/security/faillock.conf",
            "/etc/pacman.conf",
            "/etc/conf.d/pacman-contrib",
        ):
            text = text.replace(
                f'Path("{path}")', f"Path({str(etc / path.removeprefix('/etc/'))!r})"
            )
        text = (
            text.replace("if os.geteuid() != 0:", "if False:")
            .replace("if os.geteuid() == 0:", "if False:")
            .replace("info.st_uid != 0", "info.st_uid != os.getuid()")
        )
        (scripts / name).write_text(text)
    helper = source / ".chezmoitemplates/lib/policy_files.py"
    text = helper.read_text().replace("parent.st_uid != 0", "parent.st_uid != os.getuid()")
    text = text.replace(
        "os.chown(stage, 0, 0)", "os.chown(stage, os.getuid(), os.getgid())"
    ).replace("== (0, 0, mode)", "== (os.getuid(), os.getgid(), mode)")
    # Inject only actual publication failure/interruption points. The normal
    # path still executes the complete production snapshot/publication code.
    text = text.replace(
        "        os.replace(stage, path)",
        """        if path.name == os.environ.get("FAIL_REPLACE"):
            if os.environ.get("ROLLBACK_CONFLICT"):
                target = Path(os.environ["POLICY_ETC"]) / "sudoers.d/timeout"
                target.chmod(0o640)
                target.write_text("external edit\\n")
            if os.environ.get("INTERRUPT"):
                raise SystemExit(143)
            raise OSError(5, "fixture publication failure")
        os.replace(stage, path)""",
    )
    helper.write_text(text)
    env.update(POLICY_SOURCE=str(source), POLICY_ETC=str(etc))
    stub(
        env,
        "sudo",
        """case "$1" in
    -v) exit "${SUDO_STATUS:-0}" ;;
    -n) shift; unset CHEZMOI_SOURCE_DIR CHEZMOI_WORKING_TREE DOTFILES_PERSONAL_ENABLED DOTFILES_DISTRO_FAMILY; exec "$@" ;;
    systemctl) exec "$@" ;;
    *) exit 97 ;;
esac""",
        log=True,
    )
    for name in ("visudo", "pacman-conf"):
        native = shutil.which(name)
        assert native is not None, f"Required native policy validator: {name}"
        stub(
            env,
            name,
            f'''if [ "${{CONCURRENT:-}}" = '{name}' ] && [ ! -e "$HOME/changed" ]; then
    case "$*" in
        *candidate*) ;;
        *) chmod u+w "$POLICY_ETC/{"sudoers.d/timeout" if name == "visudo" else "pacman.conf"}"; printf '# external edit\\n' >> "$POLICY_ETC/{"sudoers.d/timeout" if name == "visudo" else "pacman.conf"}"; touch "$HOME/changed" ;;
    esac
fi
if [ '{name}' = visudo ]; then
    [ "${{VISUDO_STATUS:-0}}" = 0 ] || exit "$VISUDO_STATUS"
    if [ "$3" = "$POLICY_ETC/sudoers" ]; then
        if [ -e "$HOME/full-checked" ] && [ "${{POSTCHECK_STATUS:-0}}" != 0 ]; then exit "$POSTCHECK_STATUS"; fi
        touch "$HOME/full-checked"
    fi
fi
exec {native} "$@"''',
            log=True,
        )
    stub(env, "paccache", "exit 0")
    stub(env, "mise", 'exit "${MISE_STATUS:-0}"', log=True)
    stub(env, "systemctl", 'exit "${SYSTEMCTL_STATUS:-0}"', log=True)
    return env


def run_policy(policy: dict[str, str], hook: str):
    rendered = render_python(policy, hook, source=Path(policy["POLICY_SOURCE"]))
    return run_setup(policy, ["/usr/bin/python3", "-B", str(rendered)])


@pytest.mark.parametrize("hook", HOOKS, ids=["sudo", "pacman"])
@pytest.mark.parametrize("personal", [False, True], ids=["nonpersonal", "personal"])
def test_policy_direct_apply_isolated_and_idempotent(
    policy: dict[str, str], tmp_path: Path, hook: str, personal: bool
) -> None:
    assert CHEZMOI is not None
    source = Path(policy["POLICY_SOURCE"])
    for other in HOOKS:
        if other != hook:
            (source / ".chezmoiscripts/linux" / other).unlink()
    config = tmp_path / "chezmoi.json"
    config.write_text(
        json.dumps(
            {
                "data": {"personal": personal},
                "scriptEnv": {"DOTFILES_PERSONAL_ENABLED": "1" if personal else "0"},
                "interpreters": {"py": {"command": "/usr/bin/python3", "args": ["-B"]}},
            }
        )
    )
    command = [
        CHEZMOI,
        "--config",
        str(config),
        "--source",
        str(source),
        "--working-tree",
        str(source.parent),
        "--destination",
        str(tmp_path),
        "apply",
    ]
    etc = Path(policy["POLICY_ETC"])
    before = {path: path.read_bytes() for path in etc.rglob("*") if path.is_file()}
    result = run_setup(policy, command)
    assert result.returncode == 0, result.stderr
    observed = calls(policy)
    after = {
        path: (path.read_bytes(), path.stat().st_mtime_ns)
        for path in etc.rglob("*")
        if path.is_file()
    }
    if not personal:
        assert observed == []
        assert {path: value[0] for path, value in after.items()} == before
    elif hook == HOOKS[0]:
        assert (etc / "sudoers.d/timeout").read_text() == "Defaults passwd_timeout=0\n"
        assert (etc / "sudoers.d/passwd_tries").read_text() == "Defaults passwd_tries=10\n"
        assert (etc / "sudoers.d/keep_env").read_text() == 'Defaults env_keep += "EDITOR VISUAL"\n'
        assert (etc / "sudoers.d/unmanaged").read_bytes() == before[etc / "sudoers.d/unmanaged"]
        assert (etc / "security/faillock.conf").stat().st_mode & 0o777 == 0o640
        assert (
            (etc / "security/faillock.conf").read_text()
            == "# keep\ndeny=20\nlocal_users_only\n\nunlock_time=120\n\nfail_interval=900\n"
        )
        assert all(
            (etc / "sudoers.d" / name).stat().st_mode & 0o777 == 0o440
            for name in ("timeout", "passwd_tries", "keep_env")
        )
    else:
        content = (etc / "pacman.conf").read_text()
        assert "ParallelDownloads = 5\nILoveCandy\n" in content
        assert content.endswith("[custom]\nServer = https://example.invalid/$repo/os/$arch\n")
        assert (etc / "pacman-options").read_bytes() == before[etc / "pacman-options"]
        assert (
            etc / "conf.d/pacman-contrib"
        ).read_text() == "# cache\nPACCACHE_ARGS='-k2'\nOTHER=keep\n"
        native = run_setup(
            policy, ["pacman-conf", "--config", str(etc / "pacman.conf"), "NoExtract"]
        )
        assert native.returncode == 0, native.stderr
        assert native.stdout.splitlines()[-1] == "etc/pacman.d/mirrorlist"
        assert [call[0] for call in observed][-2:] == ["sudo", "systemctl"]
        assert [call for call in observed if call[0] == "mise"] == [
            ["mise", "--env", "", "bootstrap", "--only", "files", "--yes"]
        ]
    # First let run_onchange skip, then force the workflow to inspect real state.
    for force in (False, True):
        if force:
            target = source / ".chezmoiscripts/linux" / hook
            target.write_text(target.read_text() + "\n# Recheck configured state.\n")
        result = run_setup(policy, command)
        assert result.returncode == 0, result.stderr
        assert "[INFO]" not in result.stderr
        assert {path: (path.read_bytes(), path.stat().st_mtime_ns) for path in after} == after
    if personal:
        invocation = next(call for call in observed if "--apply-policy" in call)
        executable = Path(invocation[invocation.index("--apply-policy") - 1])
        assert invocation[-2:] == [str(source), "1"]
        assert executable.parent != source / ".chezmoiscripts/linux" and not executable.exists()
    assert not list(etc.rglob(".chezmoi-*"))
    if hook == HOOKS[0] and not personal:
        # Fresh-install profiles are fixed: changing only the environment does
        # not make a successfully skipped plain run_onchange hook eligible.
        config.write_text(
            json.dumps(
                {"data": {"personal": True}, "scriptEnv": {"DOTFILES_PERSONAL_ENABLED": "1"}}
            )
        )
        observed = calls(policy)
        result = run_setup(policy, command)
        assert result.returncode == 0, result.stderr
        assert calls(policy) == observed
        assert {path: path.read_bytes() for path in after} == before


@pytest.mark.parametrize("hook", HOOKS, ids=["sudo", "pacman"])
def test_privileged_policy_rejects_relative_source_without_environment(
    policy: dict[str, str], hook: str
) -> None:
    script = render_python(policy, hook, source=Path(policy["POLICY_SOURCE"]))
    policy.pop("CHEZMOI_SOURCE_DIR")
    policy.pop("DOTFILES_PERSONAL_ENABLED")
    args = ["--apply-policy", "relative-source", "1"]
    result = run_setup(policy, ["/usr/bin/python3", "-B", str(script), *args])
    assert result.returncode == 1, result.stderr
    assert "absolute" in result.stderr
    assert calls(policy) == []
    assert not (Path(policy["POLICY_ETC"]) / "sudoers.d/passwd_tries").exists()


def test_missing_runtime_worktree_stops_before_privileged_policy(policy: dict[str, str]) -> None:
    script = render_python(policy, HOOKS[1], source=Path(policy["POLICY_SOURCE"]))
    policy.pop("CHEZMOI_WORKING_TREE")
    result = run_setup(policy, ["/usr/bin/python3", "-B", str(script)])
    assert result.returncode == 1, result.stderr
    assert "CHEZMOI_WORKING_TREE" in result.stderr
    assert calls(policy) == []
    assert (
        Path(policy["POLICY_ETC"]) / "conf.d/pacman-contrib"
    ).read_text() == "# cache\nPACCACHE_ARGS='-k3'\nOTHER=keep\n"


@pytest.mark.parametrize("invalid", ["candidate", "existing"])
def test_invalid_sudoers_never_activates_candidates(policy: dict[str, str], invalid: str) -> None:
    etc = Path(policy["POLICY_ETC"])
    if invalid == "candidate":
        hook = Path(policy["POLICY_SOURCE"]) / ".chezmoiscripts/linux" / HOOKS[0]
        hook.write_text(hook.read_text().replace("Defaults passwd_timeout=0", "Defaults !"))
    else:
        (etc / "sudoers").write_text("Defaults !\n")
    result = run_policy(policy, HOOKS[0])
    assert result.returncode != 0
    assert "exit" in result.stderr
    log = Path(policy["XDG_STATE_HOME"]) / "chezmoi/logs/setup.log"
    assert "syntax error" in log.read_text()
    assert (etc / "sudoers.d/timeout").read_text() == "Defaults passwd_timeout=5\n"
    assert not (etc / "sudoers.d/passwd_tries").exists()
    assert not list(etc.rglob(".chezmoi-*"))


@pytest.mark.parametrize(
    ("hook", "target"),
    [
        (HOOKS[0], "sudoers.d/timeout"),
        (HOOKS[0], "security/faillock.conf"),
        (HOOKS[1], "pacman.conf"),
        (HOOKS[1], "conf.d/pacman-contrib"),
    ],
)
def test_policy_refuses_symlink_targets(
    policy: dict[str, str], tmp_path: Path, hook: str, target: str
) -> None:
    outside = tmp_path / "outside"
    outside.write_text("preserve\n")
    path = Path(policy["POLICY_ETC"]) / target
    path.unlink()
    path.symlink_to(outside)
    result = run_policy(policy, hook)
    assert result.returncode == 1
    assert "non-regular" in result.stderr
    assert outside.read_text() == "preserve\n"


@pytest.mark.parametrize(
    ("hook", "failure"), [(HOOKS[0], "faillock.conf"), (HOOKS[1], "pacman-contrib")]
)
@pytest.mark.parametrize("interrupt", [False, True], ids=["publication-failure", "interruption"])
def test_policy_failure_rolls_back_its_own_changes_and_retries(
    policy: dict[str, str], hook: str, failure: str, interrupt: bool
) -> None:
    etc = Path(policy["POLICY_ETC"])
    before = {
        path: (path.read_bytes(), path.stat().st_mode, path.stat().st_uid, path.stat().st_gid)
        for path in etc.rglob("*")
        if path.is_file()
    }
    policy["FAIL_REPLACE"] = failure
    if interrupt:
        policy["INTERRUPT"] = "1"
    result = run_policy(policy, hook)
    assert result.returncode == (143 if interrupt else 1), result.stderr
    assert {
        path: (path.read_bytes(), path.stat().st_mode, path.stat().st_uid, path.stat().st_gid)
        for path in etc.rglob("*")
        if path.is_file()
    } == before
    assert not list(etc.rglob(".chezmoi-*"))
    policy.pop("FAIL_REPLACE")
    result = run_policy(policy, hook)
    assert result.returncode == 0, result.stderr


@pytest.mark.parametrize(
    ("hook", "command", "target"),
    [(HOOKS[0], "visudo", "sudoers.d/timeout"), (HOOKS[1], "pacman-conf", "pacman.conf")],
)
def test_policy_preserves_concurrent_changes(
    policy: dict[str, str], hook: str, command: str, target: str
) -> None:
    policy["CONCURRENT"] = command
    result = run_policy(policy, hook)
    assert result.returncode == 1
    assert "changed before publication" in result.stderr
    assert (Path(policy["POLICY_ETC"]) / target).read_text().endswith("external edit\n")


def test_sudo_rollback_preserves_a_later_external_edit(policy: dict[str, str]) -> None:
    policy.update(FAIL_REPLACE="faillock.conf", ROLLBACK_CONFLICT="1")
    result = run_policy(policy, HOOKS[0])
    assert result.returncode == 1
    etc = Path(policy["POLICY_ETC"])
    assert (etc / "sudoers.d/timeout").read_text() == "external edit\n"
    assert not (etc / "sudoers.d/passwd_tries").exists()
    log = Path(policy["XDG_STATE_HOME"]) / "chezmoi/logs/setup.log"
    assert "Skipped rollback" in log.read_text()


@pytest.mark.parametrize(
    ("variable", "hook"),
    [
        ("SUDO_STATUS", HOOKS[0]),
        ("VISUDO_STATUS", HOOKS[0]),
        ("MISE_STATUS", HOOKS[1]),
        ("SYSTEMCTL_STATUS", HOOKS[1]),
    ],
)
def test_policy_preserves_external_failure_status(
    policy: dict[str, str], variable: str, hook: str
) -> None:
    policy[variable] = "23"
    result = run_policy(policy, hook)
    assert result.returncode == 23, result.stderr
    assert "exit 23" in result.stderr


def test_sudo_postcheck_failure_rolls_back_all_policy_files(policy: dict[str, str]) -> None:
    etc = Path(policy["POLICY_ETC"])
    before = {path: path.read_bytes() for path in etc.rglob("*") if path.is_file()}
    policy["POSTCHECK_STATUS"] = "23"
    result = run_policy(policy, HOOKS[0])
    assert result.returncode == 23, result.stderr
    assert {path: path.read_bytes() for path in etc.rglob("*") if path.is_file()} == before


@pytest.mark.parametrize("unsafe", ["symlink", "writable"])
def test_sudo_refuses_unsafe_policy_directory(policy: dict[str, str], unsafe: str) -> None:
    directory = Path(policy["POLICY_ETC"]) / "sudoers.d"
    if unsafe == "symlink":
        target = directory.with_name("elsewhere")
        directory.rename(target)
        directory.symlink_to(target, target_is_directory=True)
    else:
        directory.chmod(0o777)
    result = run_policy(policy, HOOKS[0])
    assert result.returncode == 1
    assert "directory" in result.stderr
    assert (directory / "timeout").read_text() == "Defaults passwd_timeout=5\n"


def test_pacman_mirror_exclusion_keeps_an_unterminated_last_option(policy: dict[str, str]) -> None:
    config = Path(policy["POLICY_ETC"]) / "pacman.conf"
    config.write_text("[options]\nArchitecture = auto\nColor")
    result = run_policy(policy, HOOKS[1])
    assert result.returncode == 0, result.stderr
    assert (
        config.read_text()
        == "[options]\nArchitecture = auto\nColor\nNoExtract = etc/pacman.d/mirrorlist\n"
    )
    result = run_setup(policy, ["pacman-conf", "--config", str(config), "NoExtract"])
    assert result.returncode == 0, result.stderr
    assert result.stdout.splitlines() == ["etc/pacman.d/mirrorlist"]
