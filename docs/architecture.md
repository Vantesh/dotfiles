# Repository architecture and engineering constraints

This document is the architectural source of truth for the Python and Mise migration. Repository-wide agent instructions live in \`AGENTS.md\`. If an implementation appears to conflict with these decisions, stop and ask rather than silently choosing a different design.

## Goals

- Keep the repository understandable, portable, and easy to maintain over time.
- Give each tool a clear responsibility; do not build wrappers around capabilities the tools already provide.
- Keep implementation simple and cohesive. Add structure only when it separates a real responsibility.
- Make the repository itself the source of truth. Avoid machine-specific setup steps and external symlink registration unless a configuration is intentionally global.
- Preserve existing provisioning behavior unless a migration step explicitly calls for a behavior change.

Portability is an architectural constraint, not a claim that all provisioning targets are currently supported. The existing system setup remains Arch-family focused. Do not expand OS support as part of this migration.

## Target repository layout

The intended structure is:

\`\`\`text
dotfiles/
├── .gitignore
├── fnox.toml
├── pyproject.toml
├── uv.lock
├── mise/
│   ├── config.toml
│   ├── config.local.toml       # optional, machine-local and ignored
│   ├── conf.d/
│   └── tasks/
├── src/
│   └── dotfiles/
│       ├── __init__.py
│       └── ...
├── tests/
├── home/
└── docs/
\`\`\`

This is a target, not a requirement to create empty directories or placeholder files. Add a directory when its first real file is needed.

### Mise

- The project configuration is \`mise/config.toml\`; do not introduce a competing root \`mise.toml\`.
- Put reusable project configuration fragments under \`mise/conf.d/\`.
- Put task entrypoints under \`mise/tasks/\`. Mise discovers this directory natively; do not add a redundant \`task_config.includes\` merely to register it.
- Use Mise for tool versions, package/service management, and task orchestration.
- Keep \`fnox.toml\` at the repository root.
- Do not require global symlinks for project configuration. Register a fragment globally only when it is deliberately intended to affect work outside this repository.
- Keep machine-specific overrides optional, local, and out of version control.

### Python

- Use the \`src/\` package layout: import the package as \`dotfiles\`, with implementation under \`src/dotfiles/\`.
- Use normal package imports such as \`from dotfiles.system import ...\`.
- Do not use a generic top-level \`lib\` import namespace, modify \`sys.path\`, set a global \`PYTHONPATH\`, or rely on the current working directory for imports.
- Keep reusable implementation in the Python package. Keep Mise tasks and Chezmoi lifecycle hooks thin: they should select and invoke work, not duplicate its business logic.
- Prefer the Python standard library. Add a dependency only when it materially improves correctness or maintainability.
- Avoid catch-all modules such as \`utils.py\`, \`helpers.py\`, or \`common.py\`. Organize by cohesive responsibility and deepen modules rather than spreading logic across shallow layers.
- Do not add console-script entrypoints or a second general-purpose CLI unless a concrete use case requires one. Mise tasks are the workflow interface.

### Python environment and tool ownership

There is one owner for each concern:

| Concern | Owner |
|---|---|
| Python and standalone developer tool versions | Mise |
| uv executable version | Mise |
| Project virtual environment and Python dependencies | uv |
| Python project metadata, build configuration, dependencies, pytest and Ruff configuration | \`pyproject.toml\` |
| Locked Python dependency resolution | \`uv.lock\` |
| Workflow orchestration | Mise tasks |

- Use Python 3.14 for the project.
- Use uv as the project environment and dependency manager. \`uv sync --locked\` provisions the environment from the committed lockfile.
- Use \`uv run <command>\` for project Python commands so they execute in the project environment without hardcoded virtual-environment paths or manual activation.
- Declare application/runtime dependencies in project dependencies; declare test-only dependencies in a development dependency group.
- Loguru, when used by package runtime code, is a project runtime dependency. pytest is a development dependency.
- Manage Ruff and BasedPyright versions through Mise rather than declaring duplicate tool versions in uv dependencies. Keep their configuration in \`pyproject.toml\`.
- Do not introduce a second requirements file or a second Python lockfile.
- The project must be installable from its \`src/\` layout using standard packaging metadata and a build backend. Do not compensate with import-path hacks.

## Responsibilities and boundaries

- **Chezmoi** owns managed home files, templates, profiles, and its native apply lifecycle.
- **Mise** owns tool versions, packages, services, and task orchestration.
- **uv** owns the project Python environment and dependency resolution.
- **Python package (\`src/dotfiles\`)** owns nontrivial reusable provisioning and system logic.
- **Shell** is appropriate for short, direct shell operations and bootstrap work that must run before Python is available. Do not use Bash as a general implementation language when Python is clearer or more portable.

Keep privilege boundaries visible. Pass required paths and values explicitly where execution context changes; do not depend on inherited shell state across privilege boundaries.

## Configuration and portability

- Discover paths and platform details at runtime when they are not invariant.
- Do not hardcode usernames, home directories, checkout paths, device names, PCI addresses, or machine-specific values.
- Use XDG defaults where applicable.
- Keep platform-specific behavior explicit and isolated at the platform boundary. Do not pretend an Arch-specific operation is cross-platform.
- Prefer upstream tool capabilities and documented configuration over custom registration, wrappers, or scripts.
- Never place secrets in tracked configuration, shared environment variables, logs, or test fixtures.

## Implementation quality

- State assumptions when they affect behavior. Ask before broadening scope or changing an agreed constraint.
- Make the smallest change that completes the requested step.
- Do not add speculative abstractions, options, compatibility layers, fallback paths, or frameworks.
- Do not refactor unrelated code or change working behavior incidentally.
- Make idempotency a requirement for provisioning: inspect current state, change only what is needed, and leave unrelated or unmanaged state alone.
- Use argument arrays with subprocess APIs; avoid shell command construction unless shell semantics are actually needed.
- Avoid import-time side effects and mutable global provisioning state.
- Catch exceptions only when adding useful context, performing cleanup/recovery, or reporting at the correct boundary. Do not hide unexpected failures.

## Testing and validation

- Keep tests focused on plausible regressions and consequential behavior. Do not add a test for every function or configuration line.
- Prefer tests of behavior and architectural contracts over tests that freeze file inventories, incidental paths, or implementation details.
- Discover files dynamically where possible. Hardcode only genuine public entrypoints or stable contracts.
- Use pytest for behavioral tests. Keep fixtures small and avoid unnecessary testing frameworks or elaborate mock layers.
- Run relevant format, lint, type-check, syntax, configuration, and behavioral checks for each migration step.
- Test privileged or destructive behavior only in isolated fixtures/environments, never against the development machine's live boot or filesystem configuration.
- Report exactly what was run, what passed, and what could not be verified.

## Out of scope

Unless separately requested, this migration must not:
- Change the behavior or policy of existing provisioning, personal/nonpersonal profiles, packages, services, desktop setup, networking, storage, boot, Secure Boot, credentials, or security controls.
- Add Windows, Fedora, macOS, or other OS provisioning support. Keep future portability in mind without expanding current support.
- Replace Chezmoi, Mise, fnox, or uv with another tool.
- Add a generic framework, plugin architecture, custom task runner, second CLI, or compatibility layer.
- Reorganize unrelated dotfiles or perform broad cleanup.

When a requested change appears to require one of these exclusions, stop and get explicit direction.
