# Python and Mise migration plan

## Purpose

Move the repository toward the architecture in [architecture.md](architecture.md) without changing the behavior of the existing workstation setup. This document defines migration order and scope; it is not permission to perform unrelated cleanup.

## Migration invariants

- Preserve existing provisioning behavior and privilege boundaries unless a specific change is approved.
- Keep the current Arch-family provisioning target. Future portability must not become an unrequested cross-platform implementation.
- Keep Chezmoi responsible for managed files and its apply lifecycle; Mise remains the workflow orchestrator; Python owns substantial reusable implementation.
- Avoid parallel old/new implementations. Once a component is migrated and verified, remove its replaced implementation and update its callers in the same step.
- Do not leave compatibility shims for the old repository layout.
- Make each phase small enough to review and validate before continuing.

## Phases

### 1. Establish the Python project

- Add project metadata and a build backend to `pyproject.toml` for the `src/dotfiles` package.
- Define runtime and development dependencies in the project metadata.
- Keep Python and standalone developer tools under Mise version management.
- Configure uv to create the project environment and install the package in editable development mode.
- Generate and commit `uv.lock`; ignore the local `.venv/`.
- Add only the package files needed to prove the install/import workflow.

**Verification:** run `uv sync --locked`, import the installed `dotfiles` package through `uv run`, and verify imports do not depend on the repository working directory or `PYTHONPATH`.

### 2. Establish native Mise configuration and task discovery

- Use `mise/config.toml` as the project configuration.
- Put project configuration fragments under `mise/conf.d/`.
- Put task entrypoints under `mise/tasks/`, using Mise's native task discovery.
- Remove redundant task-directory registration when the native directory is used.
- Keep local overrides ignored and optional; add the local config path to `.gitignore` when introducing it.
- Do not add global symlinks as a prerequisite for using the repository.

**Verification:** inspect Mise's resolved configuration and task list from the repository; run a minimal task from the repository root and a nested directory. Confirm project tasks work without global fragment registration.

### 3. Move reusable Python implementation

- Move reusable code into cohesive modules under `src/dotfiles/`.
- Update Chezmoi hooks and Mise tasks to invoke the package through the managed project environment where appropriate.
- Keep hook/task files thin and preserve ordering, privilege boundaries, environment handling, logging, and idempotency.
- Avoid moving code solely to match a proposed directory tree; each module must have a clear responsibility.

**Verification:** run focused tests for each migrated workflow and compare observable behavior with the pre-migration behavior.

### 4. Migrate tests and static analysis

- Move behavioral tests to the project `tests/` directory.
- Update test discovery and tool configuration in `pyproject.toml`.
- Use pytest through `uv run`.
- Move Ruff configuration into `pyproject.toml` and remove the separate `ruff.toml` once the new configuration is verified.
- Replace the existing Pyrefly setup with Mise-managed BasedPyright; do not retain both type checkers.
- Remove obsolete checks and tests only when the migrated architecture makes them redundant; preserve checks that protect meaningful behavior.

**Verification:** run the focused test suite, Ruff, BasedPyright, Python syntax checks, and relevant Chezmoi/Mise validation.

### 5. Update automation and documentation

- Update CI and Mise tasks to use the same locked, reproducible project workflow.
- Remove old setup instructions that install Python dependencies globally or describe the old source layout.
- Keep user-facing README instructions concise; keep architectural details here and in `architecture.md`.

**Verification:** confirm local and CI commands use the same toolchain and lockfile, and search the repository for stale references to the old Python/test paths and old dependency workflow.

## Completion criteria

The migration is complete when:

1. Python implementation is imported as the installed `dotfiles` package from `src/dotfiles/`.
2. Project dependencies are reproducible from `uv.lock`.
3. Project Python commands run through `uv run`; no workflow hardcodes `.venv` interpreter paths or requires activation.
4. Mise uses `mise/config.toml`, native `mise/tasks/` discovery, and project-local fragments without mandatory global symlinks.
5. Tests and static analysis run from the documented Mise workflow.
6. Existing provisioning behavior and safety boundaries remain intact.
7. No obsolete parallel implementation, import-path workaround, or contradictory documentation remains.
